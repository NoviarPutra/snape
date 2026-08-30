from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import ChatPipeline, StreamDoneEvent, StreamTokenEvent
from app.services.llm_service import MockLLMService


@pytest.mark.asyncio
async def test_chat_pipeline_stream_turn(db_session: AsyncSession) -> None:
    # 1. Setup user and session
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Test Session"),
    )
    await db_session.commit()

    # 2. Initialize chat pipeline with mock LLM service
    mock_tokens = ["I ", "went ", "to ", "the ", "market."]
    mock_llm = MockLLMService(canned_tokens=mock_tokens)
    pipeline = ChatPipeline(llm_service=mock_llm)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Yesterday I go to market",
    ):
        events.append(event)

    # 3. Verify yielded events
    token_events = [e for e in events if isinstance(e, StreamTokenEvent)]
    done_events = [e for e in events if isinstance(e, StreamDoneEvent)]

    assert len(token_events) == len(mock_tokens)
    assert "".join([e.content for e in token_events]) == "I went to the market."

    assert len(done_events) == 1
    done = done_events[0]
    assert done.session_id == session.id
    assert done.full_text == "I went to the market."
    assert done.user_message_id is not None
    assert done.assistant_message_id is not None

    # 4. Verify database persistence
    recent_messages = await session_service.get_recent_messages(db_session, session.id, limit=10)
    assert len(recent_messages) == 2
    assert recent_messages[0].role == "user"
    assert recent_messages[0].content == "Yesterday I go to market"
    assert recent_messages[1].role == "assistant"
    assert recent_messages[1].content == "I went to the market."


@pytest.mark.asyncio
async def test_chat_pipeline_invalid_session(db_session: AsyncSession) -> None:
    mock_llm = MockLLMService()
    pipeline = ChatPipeline(llm_service=mock_llm)

    with pytest.raises(ValueError, match="Session not found"):
        async for _ in pipeline.stream_turn(
            db=db_session,
            session_id=uuid4(),
            user_content="Hello",
        ):
            pass
