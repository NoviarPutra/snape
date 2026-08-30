import asyncio
import json
import logging
from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from typing import Any

import httpx
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

    async def generate_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.2,
        response_format_json: bool = False,
    ) -> str:
        """Generate a complete text response for a conversation or extraction task."""
        tokens: list[str] = []
        async for chunk in self.stream_chat(
            system_instruction=system_instruction,
            contents=contents,
            temperature=temperature,
        ):
            tokens.append(chunk)
        return "".join(tokens)


class OmniRouteLLMService(BaseLLMService):
    """OmniRoute OpenAI-compatible gateway streaming & generation service."""

    def __init__(
        self,
        base_url: str | None = None,
        api_key: str | None = None,
        model: str | None = None,
        client: httpx.AsyncClient | None = None,
        timeout: float = 60.0,
    ) -> None:
        self.base_url = (base_url or settings.OMNIROUTE_BASE_URL).rstrip("/")
        self.api_key = api_key or settings.OMNIROUTE_API_KEY
        self.model = model or settings.OMNIROUTE_MODEL
        self.timeout = timeout
        self._external_client = client

    def _format_messages(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
    ) -> list[dict[str, str]]:
        """Normalize messages to OpenAI role/content dictionary format."""
        messages: list[dict[str, str]] = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})

        for item in contents:
            role = item.get("role", "user")
            # Convert Gemini's 'model' role to standard 'assistant'
            if role == "model":
                role = "assistant"

            # Check if contents has Gemini 'parts' or direct 'content'
            if "content" in item and isinstance(item["content"], str):
                messages.append({"role": role, "content": item["content"]})
            elif "parts" in item and isinstance(item["parts"], list):
                text_parts = [p.get("text", "") for p in item["parts"] if isinstance(p, dict)]
                messages.append({"role": role, "content": "".join(text_parts)})
            else:
                messages.append({"role": role, "content": str(item)})

        return messages

    async def _get_client(self) -> httpx.AsyncClient:
        if self._external_client is not None:
            return self._external_client
        return httpx.AsyncClient(timeout=self.timeout)

    async def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        """Stream tokens asynchronously via OmniRoute chat completions SSE endpoint."""
        messages = self._format_messages(system_instruction, contents)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
        }

        endpoint = f"{self.base_url}/chat/completions"
        client = await self._get_client()
        should_close = self._external_client is None

        try:
            async with client.stream("POST", endpoint, headers=headers, json=payload) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    line = line.strip()
                    if not line:
                        continue
                    if line.startswith("data: "):
                        data_str = line[6:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            chunk_data = json.loads(data_str)
                            choices = chunk_data.get("choices", [])
                            if choices and len(choices) > 0:
                                delta = choices[0].get("delta", {})
                                content = delta.get("content")
                                if content:
                                    yield content
                        except json.JSONDecodeError:
                            logger.debug("Failed to decode SSE JSON chunk: %s", data_str)
        finally:
            if should_close:
                await client.aclose()

    async def generate_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.2,
        response_format_json: bool = False,
    ) -> str:
        """Generate full completion via OmniRoute."""
        messages = self._format_messages(system_instruction, contents)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": False,
        }
        if response_format_json:
            payload["response_format"] = {"type": "json_object"}

        endpoint = f"{self.base_url}/chat/completions"
        client = await self._get_client()
        should_close = self._external_client is None

        try:
            response = await client.post(endpoint, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            choices = data.get("choices", [])
            if choices and len(choices) > 0:
                message = choices[0].get("message", {})
                return message.get("content", "") or ""
            return ""
        finally:
            if should_close:
                await client.aclose()


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

    def _format_gemini_contents(self, contents: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Normalize messages to Gemini format with parts and role mapping."""
        gemini_contents: list[dict[str, Any]] = []
        for item in contents:
            role = item.get("role", "user")
            if role == "assistant":
                role = "model"
            if "parts" in item:
                gemini_contents.append({"role": role, "parts": item["parts"]})
            elif "content" in item:
                gemini_contents.append({"role": role, "parts": [{"text": str(item["content"])}]})
            else:
                gemini_contents.append({"role": role, "parts": [{"text": str(item)}]})
        return gemini_contents

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

        gemini_contents = self._format_gemini_contents(contents)
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=temperature,
        )

        response = await self._client.aio.models.generate_content_stream(
            model=self.model,
            contents=gemini_contents,
            config=config,
        )

        async for chunk in response:
            if chunk.text:
                yield chunk.text

    async def generate_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.2,
        response_format_json: bool = False,
    ) -> str:
        """Generate content non-streaming via Gemini."""
        if self._client is None:
            raise RuntimeError(
                "Gemini API client is not initialized. Please provide a valid GEMINI_API_KEY."
            )

        gemini_contents = self._format_gemini_contents(contents)
        config = types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=temperature,
            response_mime_type="application/json" if response_format_json else None,
        )

        response = await self._client.aio.models.generate_content(
            model=self.model,
            contents=gemini_contents,
            config=config,
        )
        return response.text or ""


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

    async def generate_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.2,
        response_format_json: bool = False,
    ) -> str:
        """Return concatenated canned tokens."""
        return "".join(self.canned_tokens)


def get_llm_service() -> BaseLLMService:
    """Factory dependency providing the configured LLM service."""
    if settings.LLM_PROVIDER == "omniroute":
        return OmniRouteLLMService()
    return GeminiLLMService()
