from collections.abc import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.llm_service import GeminiLLMService, MockLLMService


@pytest.mark.asyncio
async def test_mock_llm_service_streaming() -> None:
    service = MockLLMService(canned_tokens=["Hello", " there!", " How", " are", " you?"])
    tokens = []
    async for token in service.stream_chat(
        system_instruction="System prompt",
        contents=[{"role": "user", "parts": [{"text": "Hi"}]}],
    ):
        tokens.append(token)

    assert "".join(tokens) == "Hello there! How are you?"


@pytest.mark.asyncio
async def test_gemini_llm_service_streaming() -> None:
    # Test with mocked google genai client
    mock_client = MagicMock()
    mock_aio = MagicMock()
    mock_models = MagicMock()
    mock_client.aio = mock_aio
    mock_aio.models = mock_models

    async def fake_stream(*args, **kwargs) -> AsyncGenerator[MagicMock, None]:
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
