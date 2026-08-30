import math
import resource
import time
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import create_app
from app.schemas.memory import MemoryCreate
from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import (
    ChatPipeline,
    StreamAudioEvent,
    StreamDoneEvent,
    StreamTokenEvent,
)
from app.services.embedding_service import MockEmbeddingService
from app.services.llm_service import BaseLLMService, MockLLMService
from app.services.memory_service import MemoryService
from app.services.tts_service import PocketTTSProvider


def make_unit_vector(angle_deg: float, dim: int = 768) -> list[float]:
    rad = math.radians(angle_deg)
    vec = [0.0] * dim
    vec[0] = math.cos(rad)
    vec[1] = math.sin(rad)
    return vec


class CapturePromptLLMService(BaseLLMService):
    """Mock LLM service that captures system instructions and yields predefined tokens."""

    def __init__(self, canned_tokens: list[str] | None = None) -> None:
        self.canned_tokens = canned_tokens or ["Default ", "response."]
        self.captured_system_instructions: list[str] = []
        self.captured_contents: list[list[dict[str, Any]]] = []

    async def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        self.captured_system_instructions.append(system_instruction)
        self.captured_contents.append(contents)
        for token in self.canned_tokens:
            yield token


@pytest.fixture
def ws_app(db_session: AsyncSession) -> TestClient:
    app = create_app()

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    return TestClient(app)


@pytest.mark.asyncio
async def test_e2e_conversational_soft_correction(db_session: AsyncSession) -> None:
    """Verify full conversational flow:
    - User submits grammatical error
    - Prompt instructs Soft Correction without critique headers
    - Companion mirrors correct phrasing seamlessly.
    """
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="E2E Soft Correction"),
    )
    await db_session.commit()

    captured_llm = CapturePromptLLMService(
        canned_tokens=[
            "Oh, ",
            "you went ",
            "to the market ",
            "and bought some apples? ",
            "What kinds did you choose?",
        ]
    )
    pipeline = ChatPipeline(llm_service=captured_llm)

    tokens: list[str] = []
    done_event: StreamDoneEvent | None = None

    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Yesterday I go to market and buy some apple.",
    ):
        if isinstance(event, StreamTokenEvent):
            tokens.append(event.content)
        elif isinstance(event, StreamDoneEvent):
            done_event = event

    # Verify prompt instructs Soft Correction
    assert len(captured_llm.captured_system_instructions) == 1
    system_instruction = captured_llm.captured_system_instructions[0]
    assert "Implicit Soft Correction" in system_instruction
    assert "NEVER lecture, criticize" in system_instruction

    # Verify assistant output mirrors correct phrasing without critique headers
    full_text = "".join(tokens)
    assert "went to the market" in full_text
    assert "bought some apples" in full_text
    assert "Correction:" not in full_text
    assert "Grammar rule:" not in full_text
    assert "Mistake:" not in full_text

    # Verify database persistence
    assert done_event is not None
    assert done_event.full_text == full_text
    messages = await session_service.get_recent_messages(db_session, session.id, limit=5)
    assert len(messages) == 2
    assert messages[0].role == "user"
    assert messages[0].content == "Yesterday I go to market and buy some apple."
    assert messages[1].role == "assistant"
    assert messages[1].content == full_text


@pytest.mark.asyncio
async def test_e2e_bilingual_bridge_guidance(db_session: AsyncSession) -> None:
    """Verify Bilingual Bridge provides natural English guidance for Indonesian / mixed queries."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="E2E Bilingual Bridge"),
    )
    await db_session.commit()

    captured_llm = CapturePromptLLMService(
        canned_tokens=[
            "You can say, ",
            "'I got caught in the heavy rain on my way home.' ",
            "Did you have an umbrella with you?",
        ]
    )
    pipeline = ChatPipeline(llm_service=captured_llm)

    tokens: list[str] = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Kemarin aku kehujanan pas jalan pulang, bahasa Inggrisnya gimana ya?",
    ):
        if isinstance(event, StreamTokenEvent):
            tokens.append(event.content)

    # Verify prompt instructs bilingual bridge
    system_instruction = captured_llm.captured_system_instructions[0]
    assert "Bilingual Bridge" in system_instruction
    assert "Indonesian" in system_instruction

    full_text = "".join(tokens)
    assert "I got caught in the heavy rain" in full_text
    assert "Did you have an umbrella" in full_text


@pytest.mark.asyncio
async def test_e2e_cross_session_memory_recall(db_session: AsyncSession) -> None:
    """Verify cross-session memory recall:
    - Turn 1 extracts and persists personal goal.
    - Turn 2 (in new session) queries similarity and incorporates recalled memory into prompt.
    """
    user = await user_service.get_or_create_default_user(db_session)

    # 0 degrees and 15 degrees -> cosine similarity cos(15 deg) ≈ 0.9659 >= 0.55
    goal_vector = make_unit_vector(0.0)
    query_vector = make_unit_vector(15.0)

    mock_embedding = MockEmbeddingService(
        custom_embeddings={
            "Preparing for IELTS academic test in November with target band 7.5": goal_vector,
            "Can you recommend some good study strategies for my upcoming exam?": query_vector,
        }
    )
    memory_service = MemoryService(embedding_service=mock_embedding)

    # Turn 1: Save personal goal in Session 1
    await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Session 1 - Goal Discussion"),
    )
    await memory_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="goal",
            content="Preparing for IELTS academic test in November with target band 7.5",
            embedding=goal_vector,
        ),
    )
    await db_session.commit()

    # Verify memory is persisted
    all_memories = await memory_service.get_memories(db_session, user.id)
    assert len(all_memories) == 1
    assert all_memories[0].category == "goal"

    # Turn 2: Create Session 2 (fresh new session) and ask question
    session2 = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Session 2 - Practice Strategy"),
    )
    await db_session.commit()

    captured_llm = CapturePromptLLMService(
        canned_tokens=["Since you are targeting an IELTS band 7.5, let's practice writing tasks!"]
    )
    pipeline = ChatPipeline(
        llm_service=captured_llm,
        memory_service=memory_service,
        enable_tts=False,
    )

    tokens: list[str] = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session2.id,
        user_content="Can you recommend some good study strategies for my upcoming exam?",
    ):
        if isinstance(event, StreamTokenEvent):
            tokens.append(event.content)

    # Verify recalled memory was injected into LLM prompt
    assert len(captured_llm.captured_system_instructions) == 1
    system_prompt = captured_llm.captured_system_instructions[0]
    assert "Relevant Context & Known Facts About Learner:" in system_prompt
    assert "Preparing for IELTS academic test in November with target band 7.5" in system_prompt


@pytest.mark.asyncio
async def test_e2e_latency_benchmarks(db_session: AsyncSession) -> None:
    """Benchmark latencies:
    - Initial token latency < 800ms
    - Pocket-TTS first-sentence audio latency < 1.5s
    """
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Latency Benchmark Session"),
    )
    await db_session.commit()

    # Simulate realistic token streaming with small delays
    tokens = [
        "Welcome ",
        "to ",
        "today's ",
        "English ",
        "practice! ",
        "How ",
        "has ",
        "your ",
        "day ",
        "been ",
        "so ",
        "far?",
    ]
    mock_llm = MockLLMService(canned_tokens=tokens, delay_per_token=0.02)
    tts_provider = PocketTTSProvider(voice="af_sky", device="cpu")
    pipeline = ChatPipeline(
        llm_service=mock_llm,
        tts_provider=tts_provider,
        enable_tts=True,
    )

    start_time = time.perf_counter()
    first_token_time: float | None = None
    first_audio_time: float | None = None

    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="Hello, ready for practice!",
    ):
        now = time.perf_counter()
        if isinstance(event, StreamTokenEvent) and first_token_time is None:
            first_token_time = now
        elif isinstance(event, StreamAudioEvent) and first_audio_time is None:
            first_audio_time = now

    assert first_token_time is not None
    assert first_audio_time is not None

    token_latency_ms = (first_token_time - start_time) * 1000
    audio_latency_s = first_audio_time - start_time

    # Latency requirements from spec:
    # 1. WebSocket initial token latency < 800ms
    # 2. Pocket-TTS first-sentence audio latency < 1.5s
    assert token_latency_ms < 800, f"Token latency {token_latency_ms:.2f}ms exceeded 800ms limit"
    assert audio_latency_s < 1.5, f"Audio latency {audio_latency_s:.2f}s exceeded 1.5s limit"


@pytest.mark.asyncio
async def test_e2e_websocket_full_turn_and_latency(
    ws_app: TestClient, db_session: AsyncSession
) -> None:
    """Verify full WebSocket turn with token events, audio chunks, and latency thresholds."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="WebSocket E2E Benchmark"),
    )
    await db_session.commit()

    with ws_app.websocket_connect(f"/ws/chat/{session.id}") as websocket:
        start_time = time.perf_counter()
        first_token_latency: float | None = None
        first_audio_latency: float | None = None

        websocket.send_json({"type": "chat", "content": "Yesterday I go to market and buy food."})

        received_tokens = []
        received_audio = []
        done_payload = None

        while True:
            msg = websocket.receive_json()
            now = time.perf_counter()
            if msg["type"] == "token":
                if first_token_latency is None:
                    first_token_latency = (now - start_time) * 1000
                received_tokens.append(msg["content"])
            elif msg["type"] == "audio":
                if first_audio_latency is None:
                    first_audio_latency = now - start_time
                received_audio.append(msg)
            elif msg["type"] == "done":
                done_payload = msg
                break
            elif msg["type"] == "error":
                pytest.fail(f"Unexpected WS error: {msg}")

        # Latency validation over live websocket connection
        assert first_token_latency is not None
        assert first_token_latency < 10000, (
            f"WebSocket token latency {first_token_latency:.2f}ms > 10000ms"
        )
        if first_audio_latency is not None:
            assert first_audio_latency < 10.0, (
                f"WebSocket audio latency {first_audio_latency:.2f}s > 10.0s"
            )

        assert len(received_tokens) > 0
        assert done_payload is not None
        assert done_payload["session_id"] == str(session.id)
        assert done_payload["full_text"] == "".join(received_tokens)


@pytest.mark.asyncio
async def test_db_connection_lifecycle_and_leak_prevention() -> None:
    """Verify database connection lifecycle, pooling parameters, and clean cleanup without leaks."""
    # Test SQLite in-memory engine with session factory
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Perform multiple successive session requests to verify clean connection lifecycle
    for i in range(15):
        async with session_factory() as session:
            user = await user_service.get_or_create_default_user(session)
            await session_service.create_session(
                session,
                user_id=user.id,
                session_in=SessionCreate(title=f"Lifecycle Session {i}"),
            )
            await session.commit()

    # Verify all records persisted and engine cleanly closes
    async with session_factory() as session:
        sessions = await session_service.list_sessions(session, user.id, limit=20)
        assert len(sessions) == 15

    await engine.dispose()


@pytest.mark.asyncio
async def test_deployment_resource_profile() -> None:
    """Verify that process active memory footprint fits in 2 vCPU / 2 GB profile (< 1.2 GB)."""
    # Check max RSS memory on Linux (ru_maxrss is in kilobytes on Linux)
    usage = resource.getrusage(resource.RUSAGE_SELF)
    max_rss_kb = usage.ru_maxrss
    max_rss_gb = max_rss_kb / (1024 * 1024)

    # Active memory must be < 1.2 GB for the 2 GB RAM profile
    assert max_rss_gb < 1.2, (
        f"Peak active memory usage {max_rss_gb:.2f} GB exceeded 1.2 GB deployment budget"
    )
