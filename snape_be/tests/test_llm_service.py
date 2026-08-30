import json
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock

import httpx
import pytest

from app.services.llm_service import (
    GeminiLLMService,
    MockLLMService,
    OmniRouteLLMService,
    get_llm_service,
)


@pytest.mark.asyncio
async def test_mock_llm_service_streaming() -> None:
    service = MockLLMService(canned_tokens=["Hello", " there!", " How", " are", " you?"])
    tokens = []
    async for token in service.stream_chat(
        system_instruction="System prompt",
        contents=[{"role": "user", "content": "Hi"}],
    ):
        tokens.append(token)

    assert "".join(tokens) == "Hello there! How are you?"


@pytest.mark.asyncio
async def test_mock_llm_service_generate_chat() -> None:
    canned_payload = json.dumps({"memories": [{"category": "fact", "content": "Loves coffee"}]})
    service = MockLLMService(canned_tokens=[canned_payload])
    result = await service.generate_chat(
        system_instruction="Extract memories",
        contents=[{"role": "user", "content": "I love coffee"}],
    )
    assert "Loves coffee" in result


@pytest.mark.asyncio
async def test_omniroute_llm_service_streaming() -> None:
    sse_lines = [
        b'data: {"id":"1","choices":[{"index":0,"delta":{"role":"assistant"}}]}\n\n',
        b'data: {"id":"1","choices":[{"index":0,"delta":{"content":"Hello"}}]}\n\n',
        b'data: {"id":"1","choices":[{"index":0,"delta":{"content":" there!"}}]}\n\n',
        b"data: [DONE]\n\n",
    ]

    async def mock_aiter_lines() -> AsyncGenerator[str, None]:
        for line in sse_lines:
            yield line.decode("utf-8").strip()

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.aiter_lines = mock_aiter_lines
    mock_response.raise_for_status = MagicMock()

    class MockStreamContext:
        async def __aenter__(self) -> MagicMock:
            return mock_response

        async def __aexit__(self, exc_type: object, exc_val: object, exc_tb: object) -> None:
            pass

    mock_client = MagicMock(spec=httpx.AsyncClient)
    mock_client.stream = MagicMock(return_value=MockStreamContext())

    service = OmniRouteLLMService(
        base_url="http://localhost:20128/v1",
        api_key="test-key",
        model="antigravity/gemini-3.7-flash-high",
        client=mock_client,
    )

    tokens = []
    async for token in service.stream_chat(
        system_instruction="You are Snape",
        contents=[{"role": "user", "content": "Hi"}],
    ):
        tokens.append(token)

    assert "".join(tokens) == "Hello there!"
    mock_client.stream.assert_called_once()


@pytest.mark.asyncio
async def test_omniroute_llm_service_generate_chat() -> None:
    content_payload = json.dumps(
        {"memories": [{"category": "fact", "content": "Lives in Jakarta"}]}
    )
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json = MagicMock(
        return_value={
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": content_payload,
                    }
                }
            ]
        }
    )
    mock_response.raise_for_status = MagicMock()

    mock_client = MagicMock(spec=httpx.AsyncClient)
    mock_client.post = AsyncMock(return_value=mock_response)

    service = OmniRouteLLMService(
        base_url="http://localhost:20128/v1",
        api_key="test-key",
        model="antigravity/gemini-3.7-flash-high",
        client=mock_client,
    )

    result = await service.generate_chat(
        system_instruction="Extract memories",
        contents=[{"role": "user", "content": "I live in Jakarta"}],
    )

    assert "Lives in Jakarta" in result
    mock_client.post.assert_called_once()


@pytest.mark.asyncio
async def test_get_llm_service_default() -> None:
    service = get_llm_service()
    assert isinstance(service, OmniRouteLLMService)


@pytest.mark.asyncio
async def test_gemini_llm_service_streaming() -> None:
    # Test with mocked google genai client
    mock_client = MagicMock()
    mock_aio = MagicMock()
    mock_models = MagicMock()
    mock_client.aio = mock_aio
    mock_aio.models = mock_models

    async def fake_stream(*args: object, **kwargs: object) -> AsyncGenerator[MagicMock, None]:
        chunks = [
            MagicMock(text="That's "),
            MagicMock(text="great "),
            MagicMock(text="to hear!"),
        ]
        for chunk in chunks:
            yield chunk

    mock_models.generate_content_stream = AsyncMock(side_effect=fake_stream)

    service = GeminiLLMService(api_key="fake-key", model="gemini-2.0-flash", client=mock_client)
    tokens = []
    async for token in service.stream_chat(
        system_instruction="You are Snape",
        contents=[{"role": "user", "parts": [{"text": "Hello"}]}],
    ):
        tokens.append(token)

    assert "".join(tokens) == "That's great to hear!"
    mock_models.generate_content_stream.assert_called_once()
