import asyncio
import logging
from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from typing import Any

from google import genai
from google.genai import types

from app.core.config import settings

logger = logging.getLogger(__name__)


class BaseLLMService(ABC):
    """Abstract interface for LLM streaming and generation."""

    @abstractmethod
    def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        """Stream token-by-token responses for a conversation."""
        ...


class GeminiLLMService(BaseLLMService):
    """Google Gemini 2.0 Flash async streaming service using google-genai SDK."""

    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        client: genai.Client | None = None,
    ) -> None:
        self.api_key = api_key or settings.GEMINI_API_KEY
        self.model = model or settings.GEMINI_MODEL
        self._client: genai.Client | None = None

        if client is not None:
            self._client = client
        elif self.api_key:
            self._client = genai.Client(api_key=self.api_key)
        else:
            logger.warning("GEMINI_API_KEY is not configured. Real API calls will fail.")

    async def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        """Stream tokens asynchronously from Gemini 2.0 Flash model."""
        if self._client is None:
            raise RuntimeError(
                "Gemini API client is not initialized. Please provide a valid GEMINI_API_KEY."
            )

        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=temperature,
        )

        response = await self._client.aio.models.generate_content_stream(
            model=self.model,
            contents=contents,
            config=config,
        )

        async for chunk in response:
            if chunk.text:
                yield chunk.text


class MockLLMService(BaseLLMService):
    """Deterministic mock LLM service for testing and offline development."""

    def __init__(
        self,
        canned_tokens: list[str] | None = None,
        delay_per_token: float = 0.0,
    ) -> None:
        self.canned_tokens = canned_tokens or [
            "Oh, ",
            "you went ",
            "to the market ",
            "and bought some apples? ",
            "What kind did you pick up?",
        ]
        self.delay_per_token = delay_per_token

    async def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        """Yield canned tokens sequentially with optional simulated network latency."""
        for token in self.canned_tokens:
            if self.delay_per_token > 0:
                await asyncio.sleep(self.delay_per_token)
            yield token


def get_llm_service() -> BaseLLMService:
    """Dependency / factory returning configured LLM service."""
    if settings.APP_ENV == "testing" and not settings.GEMINI_API_KEY:
        return MockLLMService()
    return GeminiLLMService()
