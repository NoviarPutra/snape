import json
import math
from collections.abc import AsyncGenerator
from typing import Any

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.memory import MemoryCreate
from app.schemas.session import SessionCreate
from app.services import session_service, user_service
from app.services.chat_pipeline import ChatPipeline, StreamDoneEvent
from app.services.embedding_service import MockEmbeddingService
from app.services.llm_service import BaseLLMService, MockLLMService
from app.services.memory_service import MemoryService


def make_vector_at_angle(angle_deg: float, dim: int = 768) -> list[float]:
    rad = math.radians(angle_deg)
    vec = [0.0] * dim
    vec[0] = math.cos(rad)
    vec[1] = math.sin(rad)
    return vec


class InspectableLLMService(BaseLLMService):
    """LLM service that captures system instructions and contents passed to it."""

    def __init__(self, canned_tokens: list[str] | None = None) -> None:
        self.canned_tokens = canned_tokens or ["Hello ", "there!"]
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


@pytest.mark.asyncio
async def test_cross_session_semantic_recall_and_prompt_injection(
    db_session: AsyncSession,
) -> None:
    """Verify that memories in Session A are semantically recalled in Session B."""
    # 1. Setup default user
    user = await user_service.get_or_create_default_user(db_session)

    # Angles for vectors:
    # Query: "Tell me about my favorite instrument" -> 0 deg
    # Memory: "User plays acoustic guitar" -> 20 deg (cos(20°) ≈ 0.94 >= 0.55 -> RECALLED)
    # Irrelevant Memory: "User lives in Jakarta" -> 80 deg (cos(80°) ≈ 0.17 < 0.55 -> NOT RECALLED)
    vec_query = make_vector_at_angle(0.0)
    vec_guitar = make_vector_at_angle(20.0)
    vec_jakarta = make_vector_at_angle(80.0)

    mock_emb = MockEmbeddingService(
        custom_embeddings={
            "Tell me about my favorite instrument": vec_query,
            "Plays acoustic guitar in a local band": vec_guitar,
            "Lives in Jakarta, Indonesia": vec_jakarta,
        }
    )
    mem_service = MemoryService(embedding_service=mock_emb)

    # 2. In Session 1, store memories
    await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Plays acoustic guitar in a local band",
            embedding=vec_guitar,
        ),
    )
    await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="fact",
            content="Lives in Jakarta, Indonesia",
            embedding=vec_jakarta,
        ),
    )
    await db_session.commit()

    # 3. Create Session 2 (brand new session)
    session2 = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Music Session"),
    )
    await db_session.commit()

    # 4. Stream a turn in Session 2 asking about instrument
    inspectable_llm = InspectableLLMService(canned_tokens=["You ", "play ", "guitar!"])
    pipeline = ChatPipeline(llm_service=inspectable_llm, memory_service=mem_service)

    events = []
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session2.id,
        user_content="Tell me about my favorite instrument",
    ):
        events.append(event)

    # 5. Verify prompt injection in InspectableLLMService
    assert len(inspectable_llm.captured_system_instructions) == 1
    system_prompt = inspectable_llm.captured_system_instructions[0]

    # Must contain the recalled memory
    assert "Relevant Context & Known Facts About Learner:" in system_prompt
    assert "Plays acoustic guitar in a local band" in system_prompt
    # Must NOT contain the irrelevant memory
    assert "Lives in Jakarta, Indonesia" not in system_prompt


@pytest.mark.asyncio
async def test_pipeline_end_to_end_extraction_and_websocket_payload(
    db_session: AsyncSession,
) -> None:
    """Verify that ChatPipeline extracts memories and returns them in StreamDoneEvent."""
    user = await user_service.get_or_create_default_user(db_session)
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Hobbies Discussion"),
    )
    await db_session.commit()

    class MockAioModels:
        async def generate_content(self, **kwargs: object) -> object:
            class MockResponse:
                text = json.dumps(
                    {
                        "memories": [
                            {"category": "preference", "content": "Loves baking sourdough bread"}
                        ]
                    }
                )

            return MockResponse()

    class MockAio:
        models = MockAioModels()

    class MockGenaiClient:
        aio = MockAio()

    mem_service = MemoryService(
        embedding_service=MockEmbeddingService(),
        client=MockGenaiClient(),  # type: ignore[arg-type]
    )
    mock_llm = MockLLMService(canned_tokens=["That's ", "wonderful!"])
    pipeline = ChatPipeline(llm_service=mock_llm, memory_service=mem_service)

    done_event: StreamDoneEvent | None = None
    async for event in pipeline.stream_turn(
        db=db_session,
        session_id=session.id,
        user_content="I recently started baking sourdough bread at home.",
    ):
        if isinstance(event, StreamDoneEvent):
            done_event = event

    assert done_event is not None
    assert done_event.extracted_memories == ["Loves baking sourdough bread"]

    # Verify memory is saved in database
    memories = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(memories) == 1
    assert memories[0].content == "Loves baking sourdough bread"
    assert memories[0].category == "preference"
