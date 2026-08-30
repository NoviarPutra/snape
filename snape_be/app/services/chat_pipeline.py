import base64
import logging
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.prompt_builder import (
    DEFAULT_BUFFER_SIZE,
    build_conversation_messages,
    build_system_prompt,
)
from app.core.text_sanitizer import sanitize_text_for_tts
from app.schemas.message import MessageCreate
from app.services import session_service, user_service
from app.services.llm_service import BaseLLMService, get_llm_service
from app.services.memory_service import MemoryService, get_memory_service
from app.services.sentence_chunker import SentenceChunker
from app.services.tts_service import BaseTTSProvider, get_tts_provider

logger = logging.getLogger(__name__)


@dataclass
class StreamTokenEvent:
    content: str


@dataclass
class StreamAudioEvent:
    sentence: str
    audio_base64: str
    format: str = "wav"
    sample_rate: int = 24000


@dataclass
class StreamDoneEvent:
    session_id: UUID
    user_message_id: UUID
    assistant_message_id: UUID
    full_text: str
    extracted_memories: list[str]


StreamEvent = StreamTokenEvent | StreamAudioEvent | StreamDoneEvent


class ChatPipeline:
    """Orchestrates turn-level LLM streaming, vector recall, memory extraction, and audio."""

    def __init__(
        self,
        llm_service: BaseLLMService | None = None,
        memory_service: MemoryService | None = None,
        tts_provider: BaseTTSProvider | None = None,
        enable_tts: bool | None = None,
    ) -> None:
        self.llm_service = llm_service or get_llm_service()
        self.memory_service = memory_service or get_memory_service()
        self.tts_provider = tts_provider or get_tts_provider()
        self.enable_tts = enable_tts if enable_tts is not None else settings.ENABLE_TTS

    async def stream_turn(
        self,
        db: AsyncSession,
        session_id: UUID,
        user_content: str,
        memories: list[str] | None = None,
    ) -> AsyncGenerator[StreamEvent, None]:
        """Stream response tokens and audio chunks for a user turn and persist both messages."""
        # 1. Verify session exists
        session = await session_service.get_session_by_id(db, session_id)
        if session is None:
            raise ValueError(f"Session not found for id: {session_id}")

        # 2. Get user profile
        user = await user_service.get_or_create_default_user(db)

        # 3. Retrieve short-term history buffer
        recent_history = await session_service.get_recent_messages(
            db, session_id, limit=DEFAULT_BUFFER_SIZE
        )

        # 4. Recall relevant memories if not explicitly provided
        recalled_memories: list[str] = []
        if memories is not None:
            recalled_memories = memories
        else:
            try:
                search_results = await self.memory_service.search_memories(
                    db=db,
                    user_id=user.id,
                    query=user_content,
                    threshold=0.55,
                    limit=5,
                )
                recalled_memories = [res.content for res in search_results]
            except Exception as exc:
                logger.warning("Failed to recall memories for user %s: %s", user.id, exc)

        # 5. Persist user message
        user_message = await session_service.add_message(
            db,
            session_id=session_id,
            message_in=MessageCreate(role="user", content=user_content),
        )
        await db.commit()

        # 6. Build dynamic system prompt and structured messages
        system_instruction = build_system_prompt(user=user, memories=recalled_memories)
        messages = build_conversation_messages(
            history=recent_history,
            current_user_message=user_content,
            buffer_size=DEFAULT_BUFFER_SIZE,
        )

        # 7. Stream tokens from LLM and synthesize completed sentences
        chunker = SentenceChunker() if self.enable_tts else None
        accumulated_tokens: list[str] = []

        async for token in self.llm_service.stream_chat(
            system_instruction=system_instruction,
            contents=messages,
        ):
            accumulated_tokens.append(token)
            yield StreamTokenEvent(content=token)

            if chunker is not None:
                sentences = chunker.feed(token)
                for sentence in sentences:
                    clean_text = sanitize_text_for_tts(sentence)
                    if clean_text:
                        try:
                            audio_bytes = await self.tts_provider.synthesize(clean_text)
                            if audio_bytes:
                                audio_base64 = base64.b64encode(audio_bytes).decode("ascii")
                                yield StreamAudioEvent(
                                    sentence=clean_text,
                                    audio_base64=audio_base64,
                                    format="wav",
                                    sample_rate=self.tts_provider.sample_rate,
                                )
                        except Exception as exc:
                            logger.warning(
                                "TTS synthesis failed for sentence '%s': %s", clean_text, exc
                            )

        # Flush trailing sentence buffer
        if chunker is not None:
            flushed_sentences = chunker.flush()
            for sentence in flushed_sentences:
                clean_text = sanitize_text_for_tts(sentence)
                if clean_text:
                    try:
                        audio_bytes = await self.tts_provider.synthesize(clean_text)
                        if audio_bytes:
                            audio_base64 = base64.b64encode(audio_bytes).decode("ascii")
                            yield StreamAudioEvent(
                                sentence=clean_text,
                                audio_base64=audio_base64,
                                format="wav",
                                sample_rate=self.tts_provider.sample_rate,
                            )
                    except Exception as exc:
                        logger.warning(
                            "TTS synthesis failed for flushed sentence '%s': %s", clean_text, exc
                        )

        # 8. Persist assistant response
        full_text = "".join(accumulated_tokens)
        assistant_message = await session_service.add_message(
            db,
            session_id=session_id,
            message_in=MessageCreate(
                role="assistant",
                content=full_text,
                meta_info={"model": settings.OMNIROUTE_MODEL},
            ),
        )
        await db.commit()

        # 9. Extract and persist newly revealed memories
        extracted_memories: list[str] = []
        try:
            extracted_memories = await self.memory_service.extract_and_persist(
                db=db,
                user_id=user.id,
                user_content=user_content,
                recent_history=recent_history,
            )
        except Exception as exc:
            logger.warning("Error during memory extraction in chat pipeline: %s", exc)

        # 10. Yield completion event
        yield StreamDoneEvent(
            session_id=session_id,
            user_message_id=user_message.id,
            assistant_message_id=assistant_message.id,
            full_text=full_text,
            extracted_memories=extracted_memories,
        )
