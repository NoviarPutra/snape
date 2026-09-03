import json
from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock

import httpx
import pytest

from app.services.llm_service import (
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
    sse_lines = [
        f'data: {{"id":"1","choices":[{{"index":0,"delta":{{"content":{json.dumps(content_payload)}}}}}]}}\n\n'.encode(
            "utf-8"
        ),
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

    result = await service.generate_chat(
        system_instruction="Extract memories",
        contents=[{"role": "user", "content": "I live in Jakarta"}],
    )

    assert "Lives in Jakarta" in result
    mock_client.stream.assert_called_once()


@pytest.mark.asyncio
async def test_get_llm_service_default() -> None:
    service = get_llm_service()
    assert isinstance(service, OmniRouteLLMService)


@pytest.mark.asyncio
async def test_omniroute_llm_service_retry_on_504_gateway_timeout() -> None:
    fail_response = httpx.Response(
        status_code=504,
        request=httpx.Request("POST", "https://api.omniroute.test/v1/chat/completions"),
    )

    class FailStreamContext:
        async def __aenter__(self) -> MagicMock:
            raise httpx.HTTPStatusError(
                "504 Gateway Timeout",
                request=fail_response.request,
                response=fail_response,
            )

        async def __aexit__(self, exc_type: object, exc_val: object, exc_tb: object) -> None:
            pass

    sse_lines = [
        b'data: {"id":"1","choices":[{"index":0,"delta":{"content":"Success after retry"}}]}\n\n',
        b"data: [DONE]\n\n",
    ]

    async def mock_aiter_lines() -> AsyncGenerator[str, None]:
        for line in sse_lines:
            yield line.decode("utf-8").strip()

    success_response = MagicMock()
    success_response.status_code = 200
    success_response.aiter_lines = mock_aiter_lines
    success_response.raise_for_status = MagicMock()

    class SuccessStreamContext:
        async def __aenter__(self) -> MagicMock:
            return success_response

        async def __aexit__(self, exc_type: object, exc_val: object, exc_tb: object) -> None:
            pass

    mock_client = MagicMock(spec=httpx.AsyncClient)
    mock_client.stream = MagicMock(
        side_effect=[
            FailStreamContext(),
            SuccessStreamContext(),
        ]
    )

    service = OmniRouteLLMService(
        base_url="http://localhost:20128/v1",
        api_key="test-key",
        client=mock_client,
        max_retries=2,
        retry_delay=0.01,
    )

    result = await service.generate_chat(
        system_instruction="Curate content",
        contents=[{"role": "user", "content": "Topic"}],
    )

    assert result == "Success after retry"
    assert mock_client.stream.call_count == 2


@pytest.mark.asyncio
async def test_omniroute_llm_service_retry_exceeded_raises_error() -> None:
    fail_response = httpx.Response(
        status_code=504,
        request=httpx.Request("POST", "https://api.omniroute.test/v1/chat/completions"),
    )

    class FailStreamContext:
        async def __aenter__(self) -> MagicMock:
            raise httpx.HTTPStatusError(
                "504 Gateway Timeout",
                request=fail_response.request,
                response=fail_response,
            )

        async def __aexit__(self, exc_type: object, exc_val: object, exc_tb: object) -> None:
            pass

    mock_client = MagicMock(spec=httpx.AsyncClient)
    mock_client.stream = MagicMock(
        side_effect=[
            FailStreamContext(),
            FailStreamContext(),
        ]
    )

    service = OmniRouteLLMService(
        base_url="http://localhost:20128/v1",
        api_key="test-key",
        client=mock_client,
        max_retries=1,
        retry_delay=0.01,
    )

    with pytest.raises(httpx.HTTPStatusError) as exc_info:
        await service.generate_chat(
            system_instruction="Curate content",
            contents=[{"role": "user", "content": "Topic"}],
        )

    assert exc_info.value.response.status_code == 504
    assert mock_client.stream.call_count == 2
