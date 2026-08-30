import asyncio
import json
import logging
from abc import ABC, abstractmethod
from collections.abc import AsyncGenerator
from typing import Any

import httpx

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
            if role == "model":
                role = "assistant"

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
    """Factory dependency providing the configured OmniRoute LLM service."""
    return OmniRouteLLMService()
