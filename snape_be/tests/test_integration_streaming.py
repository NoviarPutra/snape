import time

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import ChatPipeline, StreamDoneEvent, StreamTokenEvent
from app.services.llm_service import BaseLLMService, MockLLMService


@pytest.mark.asyncio
async def test_first_token_latency_and_soft_correction(db_session: AsyncSession) -> None:
    """Verify first token streaming latency (<800ms) and soft correction conversational flow."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Grammar Practice"),
    )
    await db_session.commit()

    # Canned tokens demonstrating soft correction without lecturing
    correction_tokens = [
        "Oh, ",
        "you went ",
        "to the market ",
        "and bought some apples? ",
        "What kind of apples did you pick up?",
    ]
    mock_llm = MockLLMService(canned_tokens=correction_tokens)
    pipeline = ChatPipeline(llm_service=mock_llm)

    start_time = time.perf_counter()
    first_token_time: float | None = None
    collected_tokens: list[str] = []
    done_event: StreamDoneEvent | None = None

    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Yesterday I go to market and buy some apple.",
    ):
        if isinstance(event, StreamTokenEvent):
            if first_token_time is None:
                first_token_time = time.perf_counter()
            collected_tokens.append(event.content)
        elif isinstance(event, StreamDoneEvent):
            done_event = event

    assert first_token_time is not None
    latency_ms = (first_token_time - start_time) * 1000
    # Latency to first token should be well within 800ms in our pipeline
    assert latency_ms < 800

    full_text = "".join(collected_tokens)
    assert "went to the market" in full_text
    assert "bought some apples" in full_text
    assert "Correction:" not in full_text
    assert "Grammar rule:" not in full_text

    assert done_event is not None
    assert done_event.full_text == full_text

    # Verify message history contains both user and assistant turns
    history = await session_service.get_recent_messages(db_session, session.id, limit=5)
    assert len(history) == 2
    assert history[0].role == "user"
    assert history[0].content == "Yesterday I go to market and buy some apple."
    assert history[1].role == "assistant"
    assert history[1].content == full_text


@pytest.mark.asyncio
async def test_bilingual_bridge_flow(db_session: AsyncSession) -> None:
    """Verify bilingual Indonesian/English bridge flow."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Indonesian Bridge Practice"),
    )
    await db_session.commit()

    bridge_tokens = [
        "You can say ",
        "'I got caught in the rain yesterday!' ",
        "Did you manage to find shelter, or did you get completely soaked?",
    ]
    mock_llm = MockLLMService(canned_tokens=bridge_tokens)
    pipeline = ChatPipeline(llm_service=mock_llm)

    collected_tokens: list[str] = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Kemarin aku kehujanan di jalan, bahasa Inggrisnya apa ya?",
    ):
        if isinstance(event, StreamTokenEvent):
            collected_tokens.append(event.content)

    full_text = "".join(collected_tokens)
    assert "I got caught in the rain yesterday!" in full_text
    assert "Did you manage to find shelter" in full_text


@pytest.mark.asyncio
async def test_multi_turn_history_buffering(db_session: AsyncSession) -> None:
    """Verify multi-turn conversations retain rolling 5-message context buffer."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Multi-turn Dialog"),
    )
    await db_session.commit()

    # Track received system prompts and contents across turns
    class InspectingLLMService(BaseLLMService):
        def __init__(self) -> None:
            self.calls: list[dict] = []

        async def stream_chat(
            self, system_instruction: str, contents: list, temperature: float = 0.7
        ):
            self.calls.append({
                "system_instruction": system_instruction,
                "contents": contents,
            })
            yield "Response"

    inspecting_llm = InspectingLLMService()
    pipeline = ChatPipeline(llm_service=inspecting_llm)

    # Execute 4 consecutive turns (8 messages total: 4 user + 4 assistant)
    for i in range(4):
        async for _ in pipeline.stream_turn(
            db=db_session,
            session_id=session.id,
            user_content=f"User message {i + 1}",
        ):
            pass

    assert len(inspecting_llm.calls) == 4

    # The 4th call should have:
    # 5 prior messages (buffer limit) + 1 current message = 6 contents items
    call_4_contents = inspecting_llm.calls[3]["contents"]
    assert len(call_4_contents) == 6
    # Last item in buffer for 4th call should be current message (User message 4)
    assert call_4_contents[-1]["parts"][0]["text"] == "User message 4"
