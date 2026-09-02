import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_synthesize_speech_endpoint(client: AsyncClient) -> None:
    """Test POST /api/v1/tts/synthesize with valid text returns audio bytes."""
    response = await client.post(
        "/api/v1/tts/synthesize",
        json={"text": "Hello world, this is a test audio message."},
    )
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("audio/")
    assert len(response.content) > 0


@pytest.mark.asyncio
async def test_synthesize_speech_empty_text_validation(client: AsyncClient) -> None:
    """Test POST /api/v1/tts/synthesize with empty text fails validation."""
    response = await client.post(
        "/api/v1/tts/synthesize",
        json={"text": ""},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_synthesize_speech_with_markdown_formatting(client: AsyncClient) -> None:
    """Test POST /api/v1/tts/synthesize with markdown strips formatting and returns audio."""
    response = await client.post(
        "/api/v1/tts/synthesize",
        json={"text": "**Hello** `world`! [link](https://example.com)"},
    )
    assert response.status_code == 200
    assert len(response.content) > 0
