import io
import wave

import pytest

from app.services.tts_service import (
    BaseTTSProvider,
    MockTTSProvider,
    PocketTTSProvider,
    generate_mock_wav,
    get_tts_provider,
)


def test_generate_mock_wav_validity() -> None:
    wav_bytes = generate_mock_wav(text="Hello world", sample_rate=24000)
    assert len(wav_bytes) > 44
    assert wav_bytes.startswith(b"RIFF")

    # Verify WAV header
    with wave.open(io.BytesIO(wav_bytes), "rb") as wf:
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2  # 16-bit
        assert wf.getframerate() == 24000
        assert wf.getnframes() > 0


@pytest.mark.asyncio
async def test_mock_tts_provider_async_synthesize() -> None:
    provider = MockTTSProvider(sample_rate=24000)
    assert isinstance(provider, BaseTTSProvider)

    audio_bytes = await provider.synthesize("Hello there, how are you?")
    assert len(audio_bytes) > 44
    assert audio_bytes.startswith(b"RIFF")

    # Empty text returns empty bytes
    empty_audio = await provider.synthesize("")
    assert empty_audio == b""


@pytest.mark.asyncio
async def test_pocket_tts_provider_fallback() -> None:
    provider = PocketTTSProvider(voice="af_sky", device="cpu")
    assert isinstance(provider, BaseTTSProvider)

    # When pocket_tts is not installed in the environment, it gracefully synthesizes fallback WAV
    audio_bytes = await provider.synthesize("Practicing English is great.")
    assert len(audio_bytes) > 44
    assert audio_bytes.startswith(b"RIFF")


def test_get_tts_provider_factory() -> None:
    mock_p = get_tts_provider("mock")
    assert isinstance(mock_p, MockTTSProvider)

    pocket_p = get_tts_provider("pocket_tts")
    assert isinstance(pocket_p, (PocketTTSProvider, MockTTSProvider))
