from collections.abc import AsyncGenerator
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.prompt_builder import (
    DEFAULT_BUFFER_SIZE,
    build_conversation_contents,
    build_system_prompt,
)
from app.schemas.message import MessageCreate
from app.services import session_service, user_service
from app.services.llm_service import BaseLLMService, get_llm_service


@dataclass
class StreamTokenEvent:
    content: str


@dataclass
class StreamDoneEvent:
    session_id: UUID
    user_message_id: UUID
    assistant_message_id: UUID
    full_text: str
    extracted_memories: list[str]


StreamEvent = StreamTokenEvent | StreamDoneEvent


class ChatPipeline:
    """Orchestrates turn-level LLM streaming, prompt generation, and message persistence."""

    def __init__(self, llm_service: BaseLLMService | None = None) -> None:
        self.llm_service = llm_service or get_llm_service()

    async def stream_turn(
        self,
        db: AsyncSession,
        session_id: UUID,
        user_content: str,
        memories: list[str] | None = None,
    ) -> AsyncGenerator[StreamEvent, None]:
        """Stream response tokens for a user turn and persist both messages."""
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

        # 4. Persist user message
        user_message = await session_service.add_message(
            db,
            session_id=session_id,
            message_in=MessageCreate(role="user", content=user_content),
        )
        await db.commit()

        # 5. Build dynamic system prompt and structured contents
        system_instruction = build_system_prompt(user=user, memories=memories)
        contents = build_conversation_contents(
            history=recent_history,
            current_user_message=user_content,
            buffer_size=DEFAULT_BUFFER_SIZE,
        )

        # 6. Stream tokens from LLM
        accumulated_tokens: list[str] = []
        async for token in self.llm_service.stream_chat(
            system_instruction=system_instruction,
            contents=contents,
        ):
            accumulated_tokens.append(token)
            yield StreamTokenEvent(content=token)

        # 7. Persist assistant response
        full_text = "".join(accumulated_tokens)
        assistant_message = await session_service.add_message(
            db,
            session_id=session_id,
            message_in=MessageCreate(
                role="assistant",
                content=full_text,
                meta_info={"model": settings.GEMINI_MODEL},
            ),
        )
        await db.commit()

        # 8. Yield completion event
        yield StreamDoneEvent(
            session_id=session_id,
            user_message_id=user_message.id,
            assistant_message_id=assistant_message.id,
            full_text=full_text,
            extracted_memories=[],
        )
