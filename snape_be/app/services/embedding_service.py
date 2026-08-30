import hashlib
import logging
import math
from abc import ABC, abstractmethod

from app.core.config import settings

logger = logging.getLogger(__name__)


class BaseEmbeddingService(ABC):
    """Abstract interface for generating text embeddings."""

    @abstractmethod
    async def generate_embedding(self, text: str) -> list[float]:
        """Generate a 768-dimensional float embedding for a single text string."""
        ...

    @abstractmethod
    async def generate_embeddings(self, texts: list[str]) -> list[list[float]]:
        """Generate 768-dimensional float embeddings for multiple text strings."""
        ...


class DeterministicEmbeddingService(BaseEmbeddingService):
    """Deterministic, lightweight normalized vector embedding service (zero external dependency)."""

    def __init__(
        self,
        dimension: int = 768,
        custom_embeddings: dict[str, list[float]] | None = None,
    ) -> None:
        self.dimension = dimension
        self.custom_embeddings = custom_embeddings or {}

    def _generate_deterministic_vector(self, text: str) -> list[float]:
        """Generate a deterministic unit-normalized vector using cryptographic text hashing."""
        if text in self.custom_embeddings:
            return self.custom_embeddings[text]

        raw_bytes = hashlib.sha512(text.encode("utf-8")).digest()
        values: list[float] = []
        for i in range(self.dimension):
            byte_val = raw_bytes[i % len(raw_bytes)]
            phase = (i * 37) % 360
            val = math.sin(math.radians(phase) + (byte_val / 255.0) * math.pi)
            values.append(val)

        # L2 Normalize
        norm = math.sqrt(sum(v * v for v in values))
        if norm == 0.0:
            return [1.0 / math.sqrt(self.dimension)] * self.dimension
        return [v / norm for v in values]

    async def generate_embedding(self, text: str) -> list[float]:
        """Return deterministic 768-dim normalized embedding."""
        return self._generate_deterministic_vector(text)

    async def generate_embeddings(self, texts: list[str]) -> list[list[float]]:
        """Return batch of deterministic 768-dim normalized embeddings."""
        return [self._generate_deterministic_vector(t) for t in texts]


# Alias MockEmbeddingService for backwards compatibility in tests
MockEmbeddingService = DeterministicEmbeddingService


def get_embedding_service() -> BaseEmbeddingService:
    """Dependency / factory returning configured embedding service."""
    return DeterministicEmbeddingService(dimension=settings.EMBEDDING_DIMENSION)
