import pytest

from app.services.embedding_service import (
    BaseEmbeddingService,
    MockEmbeddingService,
    get_embedding_service,
)


@pytest.mark.asyncio
async def test_mock_embedding_service_dimension_and_determinism() -> None:
    """MockEmbeddingService should produce normalized 768-dim vectors deterministically."""
    service = MockEmbeddingService()

    vec1 = await service.generate_embedding("I love playing badminton in the evening.")
    vec2 = await service.generate_embedding("I love playing badminton in the evening.")
    vec3 = await service.generate_embedding("My favorite programming language is Python.")

    assert len(vec1) == 768
    assert len(vec2) == 768
    assert len(vec3) == 768

    # Determinism: same input produces exact same embedding
    assert vec1 == vec2

    # Different inputs produce different embeddings
    assert vec1 != vec3

    # Vector is normalized (L2 norm ≈ 1.0)
    norm = sum(x * x for x in vec1) ** 0.5
    assert abs(norm - 1.0) < 1e-4


@pytest.mark.asyncio
async def test_mock_embedding_service_batch() -> None:
    """MockEmbeddingService should support batch embedding generation."""
    service = MockEmbeddingService()
    texts = ["Fact 1", "Fact 2", "Fact 3"]
    vecs = await service.generate_embeddings(texts)

    assert len(vecs) == 3
    for vec in vecs:
        assert len(vec) == 768


@pytest.mark.asyncio
async def test_mock_embedding_custom_vector_mapping() -> None:
    """MockEmbeddingService can map queries to target vectors for controlled similarity."""
    target_vec = [1.0] + [0.0] * 767
    service = MockEmbeddingService(custom_embeddings={"custom query": target_vec})

    vec = await service.generate_embedding("custom query")
    assert vec == target_vec


@pytest.mark.asyncio
async def test_get_embedding_service_factory() -> None:
    """Factory should return BaseEmbeddingService instance."""
    service = get_embedding_service()
    assert isinstance(service, BaseEmbeddingService)

