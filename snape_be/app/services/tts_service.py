import asyncio
import io
import logging
import math
import struct
import wave
from abc import ABC, abstractmethod
from functools import lru_cache
from typing import Any

from app.core.config import settings

logger = logging.getLogger(__name__)


def generate_mock_wav(
    text: str = "",
    sample_rate: int = 24000,
    duration_seconds: float = 0.2,
    frequency: float = 440.0,
) -> bytes:
    """Generates standard mono 16-bit PCM WAV audio bytes for testing and fallbacks."""
    if not text and duration_seconds <= 0:
        return b""

    # Scale duration moderately with text word count
    if text:
        word_count = max(1, len(text.split()))
        duration = min(2.0, max(0.1, word_count * 0.08))
    else:
        duration = duration_seconds

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit PCM (2 bytes per sample)
        wav_file.setframerate(sample_rate)

        num_samples = int(sample_rate * duration)
        samples = []
        for i in range(num_samples):
            t = float(i) / sample_rate
            # Soft sine wave envelope to avoid audio popping
            envelope = min(1.0, min(i / 100.0, (num_samples - i) / 100.0))
            value = int(5000.0 * envelope * math.sin(2.0 * math.pi * frequency * t))
            samples.append(struct.pack("<h", value))

        wav_file.writeframes(b"".join(samples))

    return buffer.getvalue()


class BaseTTSProvider(ABC):
    """Abstract base class for Text-To-Speech providers."""

    @property
    def sample_rate(self) -> int:
        return 24000

    @abstractmethod
    def synthesize_sync(self, text: str) -> bytes:
        """Synchronously synthesizes text into WAV audio bytes."""
        pass

    async def synthesize(self, text: str) -> bytes:
        """Asynchronously synthesizes speech in a non-blocking background thread executor."""
        if not text or not text.strip():
            return b""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self.synthesize_sync, text)


class MockTTSProvider(BaseTTSProvider):
    """Deterministic Mock TTS Provider producing valid WAV audio bytes."""

    def __init__(self, sample_rate: int = 24000) -> None:
        self._sample_rate = sample_rate

    @property
    def sample_rate(self) -> int:
        return self._sample_rate

    def synthesize_sync(self, text: str) -> bytes:
        if not text or not text.strip():
            return b""
        return generate_mock_wav(text=text, sample_rate=self._sample_rate)


class EdgeTTSProvider(BaseTTSProvider):
    """Microsoft Edge Neural TTS Provider delivering natural native English speech."""

    def __init__(
        self,
        voice: str = "en-US-ChristopherNeural",
        sample_rate: int = 24000,
    ) -> None:
        self.voice = voice
        self._sample_rate = sample_rate

    @property
    def sample_rate(self) -> int:
        return self._sample_rate

    def synthesize_sync(self, text: str) -> bytes:
        return generate_mock_wav(text=text, sample_rate=self._sample_rate)

    async def synthesize(self, text: str) -> bytes:
        if not text or not text.strip():
            return b""
        try:
            import edge_tts

            communicate = edge_tts.Communicate(text, self.voice)
            chunks: list[bytes] = []
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    chunks.append(chunk["data"])
            audio_bytes = b"".join(chunks)
            if audio_bytes:
                return audio_bytes
            return generate_mock_wav(text=text, sample_rate=self._sample_rate)
        except Exception as exc:
            logger.warning("EdgeTTS synthesis failed (%s). Falling back to mock synthesis.", exc)
            return generate_mock_wav(text=text, sample_rate=self._sample_rate)


class PocketTTSProvider(BaseTTSProvider):
    """Kyutai Pocket-TTS Provider running neural CPU speech synthesis."""

    def __init__(
        self,
        voice: str = "af_sky",
        device: str = "cpu",
        sample_rate: int = 24000,
    ) -> None:
        self.voice = voice
        self.device = device
        self._sample_rate = sample_rate
        self._model: Any = None
        self._initialized = False

    @property
    def sample_rate(self) -> int:
        return self._sample_rate

    def _load_model(self) -> Any:
        if not self._initialized:
            self._initialized = True
            try:
                import importlib

                pocket_tts = importlib.import_module("pocket_tts")

                if hasattr(pocket_tts, "load_model"):
                    self._model = pocket_tts.load_model(voice=self.voice, device=self.device)
                elif hasattr(pocket_tts, "TTSModel"):
                    self._model = pocket_tts.TTSModel.load_model(
                        voice=self.voice, device=self.device
                    )
                else:
                    self._model = pocket_tts
                logger.info(
                    "PocketTTS model loaded successfully (voice=%s, device=%s)",
                    self.voice,
                    self.device,
                )
            except Exception as exc:
                logger.warning(
                    "PocketTTS initialization unavailable (%s). Falling back to mock synthesis.",
                    exc,
                )
                self._model = None
        return self._model

    def synthesize_sync(self, text: str) -> bytes:
        if not text or not text.strip():
            return b""

        model = self._load_model()
        if model is not None:
            try:
                if hasattr(model, "synthesize_to_wav"):
                    return model.synthesize_to_wav(text)  # type: ignore[no-any-return]
                elif hasattr(model, "generate_audio"):
                    audio_data = model.generate_audio(text)
                    if isinstance(audio_data, bytes):
                        return audio_data
            except Exception as exc:
                logger.warning("PocketTTS generation failed: %s. Using fallback WAV.", exc)

        return generate_mock_wav(text=text, sample_rate=self._sample_rate)


@lru_cache
def get_tts_provider(provider_type: str | None = None) -> BaseTTSProvider:
    """Factory creating configured TTS provider instance."""
    provider_name = (provider_type or settings.TTS_PROVIDER).lower()

    if not settings.ENABLE_TTS or provider_name in ("mock", "mock_tts", "none"):
        return MockTTSProvider()

    if provider_name in ("edge_tts", "edgetts", "edge"):
        return EdgeTTSProvider(voice=settings.EDGE_TTS_VOICE)

    if provider_name in ("pocket_tts", "pocket-tts", "pockettts"):
        return PocketTTSProvider(
            voice=settings.POCKET_TTS_VOICE,
            device=settings.POCKET_TTS_DEVICE,
        )

    logger.warning("Unknown TTS provider '%s'. Defaulting to EdgeTTSProvider.", provider_name)
    return EdgeTTSProvider(voice=settings.EDGE_TTS_VOICE)
