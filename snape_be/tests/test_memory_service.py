import json
import math
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User
from app.schemas.memory import MemoryCreate
from app.services.embedding_service import MockEmbeddingService
from app.services.llm_service import BaseLLMService, MockLLMService
from app.services.memory_service import MemoryService, cosine_similarity


def create_vector_with_angle(angle_rad: float, dim: int = 768) -> list[float]:
    """Helper to create unit vector at specific angle in 2D plane for precise similarity testing."""
    vec = [0.0] * dim
    vec[0] = math.cos(angle_rad)
    vec[1] = math.sin(angle_rad)
    return vec


@pytest.mark.asyncio
async def test_cosine_similarity_math() -> None:
    """Cosine similarity returns 1.0 for identical, 0.0 for orthogonal, -1.0 for opposite."""
    v1 = [1.0, 0.0, 0.0]
    v2 = [1.0, 0.0, 0.0]
    v3 = [0.0, 1.0, 0.0]
    v4 = [-1.0, 0.0, 0.0]

    assert abs(cosine_similarity(v1, v2) - 1.0) < 1e-6
    assert abs(cosine_similarity(v1, v3) - 0.0) < 1e-6
    assert abs(cosine_similarity(v1, v4) - (-1.0)) < 1e-6


@pytest.mark.asyncio
async def test_memory_crud_and_pagination(db_session: AsyncSession) -> None:
    """Test listing, filtering by category, and deleting memories."""
    user = User(username="mem_user", native_language="Indonesian", english_level="Intermediate")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    mem_service = MemoryService(embedding_service=MockEmbeddingService())

    emb1 = await mem_service.embedding_service.generate_embedding("Lives in Bandung, Indonesia")
    emb2 = await mem_service.embedding_service.generate_embedding(
        "Prefers drinking black coffee without sugar"
    )

    # Add memories across categories
    mem1 = await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="fact",
            content="Lives in Bandung, Indonesia",
            embedding=emb1,
        ),
    )
    mem2 = await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Prefers drinking black coffee without sugar",
            embedding=emb2,
        ),
    )
    await db_session.commit()

    assert mem1 is not None
    assert mem2 is not None

    # List all memories
    all_memories = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(all_memories) == 2

    # Filter by category
    fact_memories = await mem_service.get_memories(db_session, user_id=user.id, category="fact")
    assert len(fact_memories) == 1
    assert fact_memories[0].content == "Lives in Bandung, Indonesia"

    pref_memories = await mem_service.get_memories(
        db_session, user_id=user.id, category="preference"
    )
    assert len(pref_memories) == 1
    assert pref_memories[0].content == "Prefers drinking black coffee without sugar"

    # Delete memory
    deleted = await mem_service.delete_memory(db_session, memory_id=mem1.id, user_id=user.id)
    await db_session.commit()
    assert deleted is True

    # Confirm deletion
    remaining = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(remaining) == 1
    assert remaining[0].id == mem2.id

    # Delete non-existent returns False
    not_found = await mem_service.delete_memory(db_session, memory_id=uuid.uuid4(), user_id=user.id)
    assert not_found is False


@pytest.mark.asyncio
async def test_vector_similarity_search(db_session: AsyncSession) -> None:
    """Test vector similarity search with 0.55 threshold filtering."""
    user = User(username="search_user", native_language="Indonesian", english_level="Intermediate")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Base query direction: 0 radians (similarity = cos(angle))
    query_vec = create_vector_with_angle(0.0)

    # High match: angle ~ 30 deg (cos(30°) ≈ 0.866 > 0.55)
    high_match_vec = create_vector_with_angle(math.radians(30))
    # Low match: angle ~ 70 deg (cos(70°) ≈ 0.342 < 0.55)
    low_match_vec = create_vector_with_angle(math.radians(70))

    mock_emb = MockEmbeddingService(
        custom_embeddings={
            "Likes reading sci-fi novels": high_match_vec,
            "Went to grocery store": low_match_vec,
            "sci-fi books query": query_vec,
        }
    )
    mem_service = MemoryService(embedding_service=mock_emb)

    # Insert items
    await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Likes reading sci-fi novels",
            embedding=high_match_vec,
        ),
    )
    await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="experience",
            content="Went to grocery store",
            embedding=low_match_vec,
        ),
    )
    await db_session.commit()

    # Search with threshold 0.55
    results = await mem_service.search_memories(
        db_session,
        user_id=user.id,
        query="sci-fi books query",
        threshold=0.55,
        limit=5,
    )

    assert len(results) == 1
    assert results[0].content == "Likes reading sci-fi novels"
    assert results[0].similarity >= 0.55


@pytest.mark.asyncio
async def test_memory_deduplication(db_session: AsyncSession) -> None:
    """Test that items with similarity >= 0.90 are not duplicated."""
    user = User(username="dedup_user", native_language="Indonesian", english_level="Intermediate")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Angle 0° (cos(0) = 1.0)
    base_vec = create_vector_with_angle(0.0)
    # Angle 15° (cos(15°) ≈ 0.9659 >= 0.90 -> DUPLICATE)
    dup_vec = create_vector_with_angle(math.radians(15))
    # Angle 45° (cos(45°) ≈ 0.7071 < 0.90 -> NOT duplicate)
    diff_vec = create_vector_with_angle(math.radians(45))

    mock_emb = MockEmbeddingService(
        custom_embeddings={
            "Loves espresso": base_vec,
            "Really loves espresso": dup_vec,
            "Plays acoustic guitar": diff_vec,
        }
    )
    mem_service = MemoryService(embedding_service=mock_emb)

    # 1. Add base memory
    m1 = await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Loves espresso",
            embedding=base_vec,
        ),
        deduplicate=True,
    )
    await db_session.commit()
    assert m1 is not None

    # 2. Add duplicate memory (similarity ~0.966 >= 0.90) -> should return None
    m_dup = await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Really loves espresso",
            embedding=dup_vec,
        ),
        deduplicate=True,
        deduplication_threshold=0.90,
    )
    assert m_dup is None

    # 3. Add distinct memory (similarity ~0.707 < 0.90) -> should be created
    m_diff = await mem_service.create_memory(
        db_session,
        user_id=user.id,
        memory_in=MemoryCreate(
            user_id=user.id,
            category="preference",
            content="Plays acoustic guitar",
            embedding=diff_vec,
        ),
        deduplicate=True,
        deduplication_threshold=0.90,
    )
    await db_session.commit()
    assert m_diff is not None

    # Total persisted memories should be 2
    memories = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(memories) == 2


@pytest.mark.asyncio
async def test_extract_and_persist_success(db_session: AsyncSession) -> None:
    """Test extracting and persisting memories with a mocked LLM service."""
    user = User(username="extract_user", native_language="Indonesian", english_level="Intermediate")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    mock_llm = MockLLMService(
        canned_tokens=[
            json.dumps(
                {
                    "memories": [
                        {"category": "fact", "content": "Works as an architect in Surabaya"},
                        {"category": "preference", "content": "Prefers tea over coffee"},
                    ]
                }
            )
        ]
    )

    mem_service = MemoryService(
        embedding_service=MockEmbeddingService(),
        llm_service=mock_llm,
    )

    extracted = await mem_service.extract_and_persist(
        db=db_session,
        user_id=user.id,
        user_content="I work as an architect in Surabaya and I prefer tea over coffee.",
    )

    assert len(extracted) == 2
    assert "Works as an architect in Surabaya" in extracted
    assert "Prefers tea over coffee" in extracted

    # Confirm saved in database
    db_memories = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(db_memories) == 2


@pytest.mark.asyncio
async def test_extract_and_persist_fault_tolerance(db_session: AsyncSession) -> None:
    """If extraction fails, it should degrade gracefully and return empty list."""
    user = User(
        username="fault_user",
        native_language="Indonesian",
        english_level="Intermediate",
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    failing_llm = MagicMock(spec=BaseLLMService)
    failing_llm.generate_chat = AsyncMock(
        side_effect=RuntimeError("API quota exceeded or network timeout")
    )

    mem_service = MemoryService(
        embedding_service=MockEmbeddingService(),
        llm_service=failing_llm,
    )

    # Should not raise, should return empty list
    extracted = await mem_service.extract_and_persist(
        db=db_session,
        user_id=user.id,
        user_content="I have three cats.",
    )

    assert extracted == []
    # DB state remains valid
    db_memories = await mem_service.get_memories(db_session, user_id=user.id)
    assert len(db_memories) == 0
