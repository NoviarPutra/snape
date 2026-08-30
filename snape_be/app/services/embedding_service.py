import hashlib
import logging
import math
from abc import ABC, abstractmethod

from google import genai

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


class GeminiEmbeddingService(BaseEmbeddingService):
    """Google Gemini text-embedding-004 service using google-genai SDK."""

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        client: genai.Client | None = None,
    ) -> None:
        self.api_key = api_key or settings.GEMINI_API_KEY
        self.model = model or settings.EMBEDDING_MODEL
        self._client: genai.Client | None = None

        if client is not None:
            self._client = client
        elif self.api_key:
            self._client = genai.Client(api_key=self.api_key)
        else:
            logger.warning("GEMINI_API_KEY is not configured for GeminiEmbeddingService.")

    async def generate_embedding(self, text: str) -> list[float]:
        """Generate 768-dim embedding for a single text via Gemini API."""
        if self._client is None:
            raise RuntimeError(
                "Gemini API client is not initialized. Please configure GEMINI_API_KEY."
            )

        response = await self._client.aio.models.embed_content(
            model=self.model,
            contents=text,
        )

        if not response.embeddings or len(response.embeddings) == 0:
            raise RuntimeError("Empty embedding response received from Gemini API.")

        values = response.embeddings[0].values or []
        return list(values)

    async def generate_embeddings(self, texts: list[str]) -> list[list[float]]:
        """Generate 768-dim embeddings for multiple texts."""
        if not texts:
            return []

        if self._client is None:
            raise RuntimeError(
                "Gemini API client is not initialized. Please configure GEMINI_API_KEY."
            )

        response = await self._client.aio.models.embed_content(
            model=self.model,
            contents=texts,
        )

        if not response.embeddings:
            raise RuntimeError("Empty embeddings response received from Gemini API.")

        return [list(emb.values or []) for emb in response.embeddings]


class MockEmbeddingService(BaseEmbeddingService):
    """Deterministic mock embedding service for unit testing and offline development."""

    def __init__(
        self,
        dimension: int = 768,
        custom_embeddings: dict[str, list[float]] | None = None,
    ) -> None:
        self.dimension = dimension
        self.custom_embeddings = custom_embeddings or {}

    def _generate_deterministic_vector(self, text: str) -> list[float]:
        """Generate a deterministic unit-normalized vector using text hashing."""
        if text in self.custom_embeddings:
            return self.custom_embeddings[text]

        raw_bytes = hashlib.sha512(text.encode("utf-8")).digest()
        # Expand or loop bytes to reach dimension count
        values: list[float] = []
        for i in range(self.dimension):
            byte_val = raw_bytes[i % len(raw_bytes)]
            # Deterministic variation across indices
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


def get_embedding_service() -> BaseEmbeddingService:
    """Dependency / factory returning configured embedding service."""
    if settings.APP_ENV == "testing" and not settings.GEMINI_API_KEY:
        return MockEmbeddingService(dimension=settings.EMBEDDING_DIMENSION)
    return GeminiEmbeddingService()
