import asyncio
import base64
import logging
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import settings
from app.core.prompt_builder import (
    DEFAULT_BUFFER_SIZE,
    build_conversation_messages,
    build_system_prompt,
    build_title_generation_prompt,
)
from app.core.space_config import SpaceConfig, get_space_config
from app.core.text_sanitizer import sanitize_text_for_tts
from app.db.session import async_session_factory
from app.schemas.message import MessageCreate
from app.schemas.session import SessionUpdate
from app.services import session_service, user_service
from app.services.llm_service import BaseLLMService, get_llm_service
from app.services.memory_service import MemoryService, get_memory_service
from app.services.obsidian_service import ObsidianService, get_obsidian_service
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
    """Orchestrates turn-level LLM streaming, vector recall, and Obsidian sync."""

    def __init__(
        self,
        llm_service: BaseLLMService | None = None,
        memory_service: MemoryService | None = None,
        tts_provider: BaseTTSProvider | None = None,
        obsidian_service: ObsidianService | None = None,
        enable_tts: bool | None = None,
        session_factory: async_sessionmaker[AsyncSession] | None = None,
        title_autogen_timeout: float = 5.0,
    ) -> None:
        self.llm_service = llm_service or get_llm_service()
        self.memory_service = (
            memory_service
            if memory_service is not None
            else (
                MemoryService(llm_service=self.llm_service)
                if llm_service is not None
                else get_memory_service()
            )
        )
        self.tts_provider = tts_provider or get_tts_provider()
        self.obsidian_service = obsidian_service or get_obsidian_service()
        self.enable_tts = enable_tts if enable_tts is not None else settings.ENABLE_TTS
        self.session_factory = session_factory or async_session_factory
        self.title_autogen_timeout = title_autogen_timeout
        self._background_tasks: set[asyncio.Task[None]] = set()

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

        space_config = get_space_config(session.space_slug)

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

        # 5. Load curated topics from Obsidian Vault (zero-overhead)
        curated_topics: list[str] = []
        if self.obsidian_service and self.obsidian_service.enabled:
            try:
                curated_topics = await self.obsidian_service.load_curated_topics(limit=3)
            except Exception as exc:
                logger.debug("Could not load Obsidian topics: %s", exc)

        # 6. Persist user message
        user_message = await session_service.add_message(
            db,
            session_id=session_id,
            message_in=MessageCreate(role="user", content=user_content),
        )
        await db.commit()

        # 7. Build dynamic system prompt and structured messages
        system_instruction = build_system_prompt(
            user=user,
            memories=recalled_memories,
            curated_topics=curated_topics,
            space_config=space_config,
        )
        messages = build_conversation_messages(
            history=recent_history,
            current_user_message=user_content,
            buffer_size=DEFAULT_BUFFER_SIZE,
        )

        # 8. Stream LLM tokens and synthesize audio sentences
        should_enable_tts = self.enable_tts and space_config.tts_enabled
        chunker = SentenceChunker() if should_enable_tts else None
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
                                    format=self.tts_provider.audio_format,
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

        # 9. Persist assistant response
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

        # 10. Auto-generate concise session title after exactly 5 user messages
        try:
            user_message_count = await session_service.count_user_messages(db, session_id)
            if user_message_count == 5:
                task = asyncio.create_task(
                    self._autogen_session_title(
                        session_id=session_id,
                        space_config=space_config,
                        bind_engine=db.bind,
                    )
                )
                self._background_tasks.add(task)
                task.add_done_callback(self._background_tasks.discard)
        except Exception as exc:
            logger.warning("Error checking message count for title autogen: %s", exc)

        # 11. Extract and persist newly revealed memories
        extracted_memories: list[str] = []
        try:
            extracted_memories = await self.memory_service.extract_and_persist(
                db=db,
                user_id=user.id,
                user_content=user_content,
                recent_history=recent_history,
            )
            # Sync user profile to Obsidian asynchronously
            if extracted_memories and self.obsidian_service and self.obsidian_service.enabled:
                all_memories = await self.memory_service.get_memories(
                    db=db, user_id=user.id, limit=20
                )
                await self.obsidian_service.sync_user_profile(
                    user=user,
                    memories=[m.content for m in all_memories],
                )
        except Exception as exc:
            logger.warning("Error during memory extraction in chat pipeline: %s", exc)

        # 12. Yield completion event
        yield StreamDoneEvent(
            session_id=session_id,
            user_message_id=user_message.id,
            assistant_message_id=assistant_message.id,
            full_text=full_text,
            extracted_memories=extracted_memories,
        )

    async def _autogen_session_title(
        self,
        session_id: UUID,
        space_config: SpaceConfig,
        bind_engine: AsyncEngine | AsyncConnection | None = None,
    ) -> None:
        """Background fire-and-forget task to auto-generate a concise session title."""
        try:
            async with asyncio.timeout(self.title_autogen_timeout):
                if (
                    self.session_factory is not None
                    and self.session_factory != async_session_factory
                ):
                    session_maker = self.session_factory
                elif bind_engine is not None:
                    session_maker = async_sessionmaker(
                        bind=bind_engine, class_=AsyncSession, expire_on_commit=False
                    )
                else:
                    session_maker = self.session_factory or async_session_factory

                async with session_maker() as bg_db:
                    messages = await session_service.get_recent_messages(
                        bg_db, session_id, limit=10
                    )
                    if not messages:
                        return

                    prompt = build_title_generation_prompt(space_config)
                    contents = [{"role": msg.role, "content": msg.content} for msg in messages]
                    raw_title = await self.llm_service.generate_chat(
                        system_instruction=prompt,
                        contents=contents,
                        temperature=0.2,
                    )
                    clean_title = raw_title.strip().strip("\"'").strip()
                    if clean_title:
                        clean_title = clean_title.split("\n")[0].strip().strip("\"'").strip()
                        await session_service.update_session(
                            bg_db,
                            session_id=session_id,
                            session_in=SessionUpdate(title=clean_title),
                        )
                        await bg_db.commit()
                        logger.info(
                            "Auto-generated session title for %s: '%s'",
                            session_id,
                            clean_title,
                        )
        except TimeoutError:
            logger.warning("Title generation timed out (>5s) for session %s", session_id)
        except Exception as exc:
            logger.warning("Title generation failed for session %s: %s", session_id, exc)

    async def export_session_journal(self, db: AsyncSession, session_id: UUID) -> None:
        """Export session transcript and takeaways to Obsidian vault."""
        if not self.obsidian_service or not self.obsidian_service.enabled:
            return

        try:
            session = await session_service.get_session_by_id(
                db, session_id=session_id, include_messages=True
            )
            if not session or not session.messages:
                return

            user = await user_service.get_or_create_default_user(db)
            memories = await self.memory_service.get_memories(db=db, user_id=user.id, limit=10)

            await self.obsidian_service.export_session_journal(
                session_id=session_id,
                session_title=session.title,
                messages=list(session.messages),
                memories=[m.content for m in memories],
            )
        except Exception as exc:
            logger.warning("Failed to export session journal on session finish: %s", exc)
