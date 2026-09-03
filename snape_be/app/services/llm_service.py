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
        response_format_json: bool = False,
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
            response_format_json=response_format_json,
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
        timeout: float | None = None,
        max_retries: int | None = None,
        retry_delay: float | None = None,
    ) -> None:
        self.base_url = (base_url or settings.OMNIROUTE_BASE_URL).rstrip("/")
        self.api_key = api_key or settings.OMNIROUTE_API_KEY
        self.model = model or settings.OMNIROUTE_MODEL
        self.timeout = timeout if timeout is not None else settings.OMNIROUTE_TIMEOUT
        self.max_retries = (
            max_retries if max_retries is not None else settings.OMNIROUTE_MAX_RETRIES
        )
        self.retry_delay = (
            retry_delay if retry_delay is not None else settings.OMNIROUTE_RETRY_DELAY
        )
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
        response_format_json: bool = False,
    ) -> AsyncGenerator[str, None]:
        """Stream tokens asynchronously via OmniRoute chat completions SSE endpoint."""
        messages = self._format_messages(system_instruction, contents)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
        }
        if response_format_json:
            payload["response_format"] = {"type": "json_object"}

        endpoint = f"{self.base_url}/chat/completions"
        attempt = 0
        yielded_any = False

        while True:
            attempt += 1
            client = await self._get_client()
            should_close = self._external_client is None

            try:
                async with client.stream(
                    "POST", endpoint, headers=headers, json=payload
                ) as response:
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
                                        yielded_any = True
                                        yield content
                            except json.JSONDecodeError:
                                logger.debug("Failed to decode SSE JSON chunk: %s", data_str)
                return
            except (httpx.TimeoutException, httpx.NetworkError, httpx.HTTPStatusError) as exc:
                status_code = getattr(getattr(exc, "response", None), "status_code", None)
                is_retryable = not yielded_any and (
                    isinstance(exc, (httpx.TimeoutException, httpx.NetworkError))
                    or status_code in (429, 500, 502, 503, 504)
                )
                if is_retryable and attempt <= self.max_retries:
                    backoff = self.retry_delay * (2 ** (attempt - 1))
                    logger.warning(
                        "OmniRoute stream attempt %d/%d failed (%s, status=%s). "
                        "Retrying in %.1fs...",
                        attempt,
                        self.max_retries + 1,
                        exc.__class__.__name__,
                        status_code,
                        backoff,
                    )
                    await asyncio.sleep(backoff)
                else:
                    raise
            finally:
                if should_close:
                    await client.aclose()


class MockLLMService(BaseLLMService):
    """Deterministic mock LLM service for testing and offline development."""

    def __init__(
        self,
        canned_tokens: list[str] | None = None,
        delay_per_token: float = 0.0,
        canned_response: str | None = None,
        generate_chat_delay: float = 0.0,
        generate_chat_error: Exception | None = None,
    ) -> None:
        self.canned_tokens = canned_tokens or [
            "Oh, ",
            "you went ",
            "to the market ",
            "and bought some apples? ",
            "What kind did you pick up?",
        ]
        self.delay_per_token = delay_per_token
        self.canned_response = canned_response
        self.generate_chat_delay = generate_chat_delay
        self.generate_chat_error = generate_chat_error
        self.last_system_instruction: str | None = None
        self.last_stream_system_instruction: str | None = None
        self.last_generate_system_instruction: str | None = None
        self.system_instructions_history: list[str] = []
        self.last_contents: list[dict[str, Any]] | None = None

    async def stream_chat(
        self,
        system_instruction: str,
        contents: list[dict[str, Any]],
        temperature: float = 0.7,
        response_format_json: bool = False,
    ) -> AsyncGenerator[str, None]:
        """Yield canned tokens with optional delay."""
        self.last_system_instruction = system_instruction
        self.last_stream_system_instruction = system_instruction
        self.system_instructions_history.append(system_instruction)
        self.last_contents = contents
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
        """Return concatenated canned tokens or canned response."""
        self.last_system_instruction = system_instruction
        self.last_generate_system_instruction = system_instruction
        self.system_instructions_history.append(system_instruction)
        self.last_contents = contents
        if self.generate_chat_delay > 0:
            await asyncio.sleep(self.generate_chat_delay)
        if self.generate_chat_error is not None:
            raise self.generate_chat_error
        if self.canned_response is not None:
            return self.canned_response
        return "".join(self.canned_tokens)


def get_llm_service() -> BaseLLMService:
    """Factory dependency providing the configured OmniRoute LLM service."""
    return OmniRouteLLMService()
