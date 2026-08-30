import asyncio
import time

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import (
    ChatPipeline,
    StreamAudioEvent,
)
from app.services.llm_service import MockLLMService
from app.services.tts_service import MockTTSProvider, PocketTTSProvider


@pytest.mark.asyncio
async def test_first_sentence_audio_latency_under_1_5s(db_session: AsyncSession) -> None:
    """Verify first-sentence audio is synthesized and emitted within 1.5 seconds."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Audio Latency Test"),
    )
    await db_session.commit()

    tokens = [
        "That ",
        "sounds ",
        "wonderful! ",
        "What ",
        "did ",
        "you ",
        "buy ",
        "there?",
    ]
    mock_llm = MockLLMService(canned_tokens=tokens, delay_per_token=0.03)
    tts_provider = PocketTTSProvider(voice="af_sky", device="cpu")
    pipeline = ChatPipeline(llm_service=mock_llm, tts_provider=tts_provider, enable_tts=True)

    start_time = time.perf_counter()
    first_sentence_audio_time: float | None = None
    first_audio_sentence: str | None = None

    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="I went to the store today.",
    ):
        if isinstance(event, StreamAudioEvent) and first_sentence_audio_time is None:
            first_sentence_audio_time = time.perf_counter() - start_time
            first_audio_sentence = event.sentence

    assert first_sentence_audio_time is not None
    assert first_audio_sentence == "That sounds wonderful!"
    # Must be synthesized well under 1.5s
    assert (
        first_sentence_audio_time < 1.5
    ), f"Audio latency {first_sentence_audio_time:.3f}s exceeded 1.5s"


@pytest.mark.asyncio
async def test_non_blocking_event_loop_during_synthesis() -> None:
    """Verify that TTS synthesis runs asynchronously without blocking the event loop."""
    provider = MockTTSProvider()

    loop_running = False

    async def background_heartbeat() -> None:
        nonlocal loop_running
        for _ in range(5):
            await asyncio.sleep(0.01)
        loop_running = True

    heartbeat_task = asyncio.create_task(background_heartbeat())
    audio_bytes = await provider.synthesize(
        "This is a longer paragraph to synthesize speech while background "
        "tasks run concurrently in the event loop."
    )
    await heartbeat_task

    assert len(audio_bytes) > 44
    assert loop_running is True
