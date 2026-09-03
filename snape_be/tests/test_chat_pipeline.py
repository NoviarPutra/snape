import asyncio
import base64
from typing import Any
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import (
    ChatPipeline,
    StreamAudioEvent,
    StreamDoneEvent,
    StreamTokenEvent,
)
from app.services.llm_service import MockLLMService
from app.services.tts_service import MockTTSProvider


@pytest.mark.asyncio
async def test_chat_pipeline_stream_turn_with_tts(db_session: AsyncSession) -> None:
    # 1. Setup user and session
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Test Session"),
    )
    await db_session.commit()

    # 2. Initialize chat pipeline with mock LLM and mock TTS service
    mock_tokens = ["I ", "went ", "to ", "the ", "market. ", "What ", "about ", "you?"]
    mock_llm = MockLLMService(canned_tokens=mock_tokens)
    mock_tts = MockTTSProvider(sample_rate=24000)
    pipeline = ChatPipeline(llm_service=mock_llm, tts_provider=mock_tts, enable_tts=True)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Yesterday I go to market",
    ):
        events.append(event)

    # 3. Verify yielded events
    token_events = [e for e in events if isinstance(e, StreamTokenEvent)]
    audio_events = [e for e in events if isinstance(e, StreamAudioEvent)]
    done_events = [e for e in events if isinstance(e, StreamDoneEvent)]

    assert len(token_events) == len(mock_tokens)
    assert "".join([e.content for e in token_events]) == "I went to the market. What about you?"

    # Should have emitted 2 audio chunks for the 2 sentences
    assert len(audio_events) == 2
    assert audio_events[0].sentence == "I went to the market."
    assert audio_events[0].format == "wav"
    assert audio_events[0].sample_rate == 24000
    assert len(base64.b64decode(audio_events[0].audio_base64)) > 44

    assert audio_events[1].sentence == "What about you?"

    assert len(done_events) == 1
    done = done_events[0]
    assert done.session_id == session.id
    assert done.full_text == "I went to the market. What about you?"
    assert done.user_message_id is not None
    assert done.assistant_message_id is not None

    # 4. Verify database persistence
    recent_messages = await session_service.get_recent_messages(db_session, session.id, limit=10)
    assert len(recent_messages) == 2
    assert recent_messages[0].role == "user"
    assert recent_messages[0].content == "Yesterday I go to market"
    assert recent_messages[1].role == "assistant"
    assert recent_messages[1].content == "I went to the market. What about you?"


@pytest.mark.asyncio
async def test_chat_pipeline_tts_disabled(db_session: AsyncSession) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="No TTS Session"),
    )
    await db_session.commit()

    mock_tokens = ["Hello ", "world."]
    mock_llm = MockLLMService(canned_tokens=mock_tokens)
    pipeline = ChatPipeline(llm_service=mock_llm, enable_tts=False)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Hi",
    ):
        events.append(event)

    audio_events = [e for e in events if isinstance(e, StreamAudioEvent)]
    assert len(audio_events) == 0


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


@pytest.mark.asyncio
async def test_chat_pipeline_tech_space_no_tts_and_indonesian_prompt(
    db_session: AsyncSession,
) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Tech Discussion", space_slug="tech"),
    )
    await db_session.commit()

    mock_tokens = ["Arsitektur ", "microservices ", "memiliki ", "trade-offs."]
    mock_llm = MockLLMService(canned_tokens=mock_tokens)
    mock_tts = MockTTSProvider(sample_rate=24000)
    pipeline = ChatPipeline(llm_service=mock_llm, tts_provider=mock_tts, enable_tts=True)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Bagaimana menurutmu tentang microservices?",
    ):
        events.append(event)

    # 1. Verify system instruction sent to LLM contains Indonesian tech instructions
    assert mock_llm.last_system_instruction is not None
    assert "software engineer senior" in mock_llm.last_system_instruction
    assert "Soft Correction" not in mock_llm.last_system_instruction

    # 2. Verify NO audio events generated because tech space has tts_enabled=False
    audio_events = [e for e in events if isinstance(e, StreamAudioEvent)]
    assert len(audio_events) == 0

    token_events = [e for e in events if isinstance(e, StreamTokenEvent)]
    assert len(token_events) == len(mock_tokens)


@pytest.mark.asyncio
async def test_chat_pipeline_english_a1_space_system_prompt(
    db_session: AsyncSession,
) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="A1 Chat", space_slug="english_a1"),
    )
    await db_session.commit()

    mock_tokens = ["Hello ", "friend."]
    mock_llm = MockLLMService(canned_tokens=mock_tokens)
    mock_tts = MockTTSProvider(sample_rate=24000)
    pipeline = ChatPipeline(llm_service=mock_llm, tts_provider=mock_tts, enable_tts=True)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Hello",
    ):
        events.append(event)

    assert mock_llm.last_system_instruction is not None
    assert "CEFR A1" in mock_llm.last_system_instruction
    assert "very simple, clear, and short sentences" in mock_llm.last_system_instruction

    # English A1 has tts_enabled=True, so audio event is generated
    audio_events = [e for e in events if isinstance(e, StreamAudioEvent)]
    assert len(audio_events) == 1


@pytest.mark.asyncio
async def test_chat_pipeline_autogens_title_on_fifth_user_message(
    db_session: AsyncSession,
) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(space_slug="english_b2"),
    )
    await db_session.commit()
    session_id = session.id
    assert session.title == "B2 – Conversational"

    mock_llm = MockLLMService(
        canned_tokens=["OK."],
        canned_response="Discussing Favorite English Novels",
    )
    pipeline = ChatPipeline(llm_service=mock_llm, enable_tts=False)

    # Turns 1 to 4: title should remain placeholder
    for i in range(1, 5):
        async for _ in pipeline.stream_turn(
            db=db_session,
            session_id=session_id,
            user_content=f"Turn message {i}",
        ):
            pass
        await asyncio.sleep(0.02)
        db_session.expire_all()
        refreshed = await session_service.get_session_by_id(db_session, session_id)
        assert refreshed is not None
        assert refreshed.title == "B2 – Conversational"

    # Turn 5: trigger title generation
    async for _ in pipeline.stream_turn(
        db=db_session,
        session_id=session_id,
        user_content="Turn message 5: I love reading 1984 by George Orwell",
    ):
        pass

    # Wait briefly for background task to finish
    await asyncio.sleep(0.1)
    db_session.expire_all()
    refreshed = await session_service.get_session_by_id(db_session, session_id)
    assert refreshed is not None
    assert refreshed.title == "Discussing Favorite English Novels"

    # Turn 6: should not re-trigger title generation
    mock_llm.canned_response = "Different Title That Should Not Apply"
    async for _ in pipeline.stream_turn(
        db=db_session,
        session_id=session_id,
        user_content="Turn message 6: Another message",
    ):
        pass

    await asyncio.sleep(0.1)
    db_session.expire_all()
    refreshed = await session_service.get_session_by_id(db_session, session_id)
    assert refreshed is not None
    assert refreshed.title == "Discussing Favorite English Novels"


@pytest.mark.asyncio
async def test_chat_pipeline_autogen_title_handles_llm_failure(
    db_session: AsyncSession,
) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(space_slug="english_b2"),
    )
    await db_session.commit()
    session_id = session.id

    mock_llm = MockLLMService(
        canned_tokens=["OK."],
        generate_chat_error=RuntimeError("LLM Gateway 500 Error"),
    )
    pipeline = ChatPipeline(llm_service=mock_llm, enable_tts=False)

    # Execute 5 turns
    for i in range(1, 6):
        events = []
        async for event in pipeline.stream_turn(
            db=db_session,
            session_id=session_id,
            user_content=f"Message {i}",
        ):
            events.append(event)
        assert any(isinstance(e, StreamDoneEvent) for e in events)

    await asyncio.sleep(0.1)
    db_session.expire_all()
    refreshed = await session_service.get_session_by_id(db_session, session_id)
    assert refreshed is not None
    # Title must remain placeholder and no exception escaped to caller
    assert refreshed.title == "B2 – Conversational"


@pytest.mark.asyncio
async def test_chat_pipeline_autogen_title_handles_timeout(
    db_session: AsyncSession,
) -> None:
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(space_slug="english_b2"),
    )
    await db_session.commit()
    session_id = session.id

    # Custom mock LLM that only delays when generating title
    class TimeoutTitleLLM(MockLLMService):
        async def generate_chat(
            self,
            system_instruction: str,
            contents: list[dict[str, Any]],
            temperature: float = 0.2,
            response_format_json: bool = False,
        ) -> str:
            if "at most 6 words" in system_instruction or "maksimal 6 kata" in system_instruction:
                await asyncio.sleep(5.2)
                return "Too Late Title"
            return await super().generate_chat(
                system_instruction,
                contents,
                temperature=temperature,
                response_format_json=response_format_json,
            )

    mock_llm = TimeoutTitleLLM(canned_tokens=["OK."])
    pipeline = ChatPipeline(llm_service=mock_llm, enable_tts=False)

    for i in range(1, 6):
        events = []
        async for event in pipeline.stream_turn(
            db=db_session,
            session_id=session_id,
            user_content=f"Message {i}",
        ):
            events.append(event)
        assert any(isinstance(e, StreamDoneEvent) for e in events)

    # Let the background timeout trigger
    await asyncio.sleep(5.3)
    db_session.expire_all()
    refreshed = await session_service.get_session_by_id(db_session, session_id)
    assert refreshed is not None
    assert refreshed.title == "B2 – Conversational"
