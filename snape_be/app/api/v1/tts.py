from fastapi import APIRouter, Response

from app.core.text_sanitizer import sanitize_text_for_tts
from app.schemas.tts import TTSSynthesizeRequest
from app.services.tts_service import get_tts_provider

router = APIRouter(prefix="/tts", tags=["TTS"])


@router.post("/synthesize")
async def synthesize_speech(
    payload: TTSSynthesizeRequest,
) -> Response:
    """Synthesize text into speech audio bytes on-demand."""
    clean_text = sanitize_text_for_tts(payload.text)
    if not clean_text:
        clean_text = payload.text

    tts_provider = get_tts_provider()
    audio_bytes = await tts_provider.synthesize(clean_text)

    media_type = "audio/mpeg" if tts_provider.audio_format == "mp3" else "audio/wav"
    return Response(
        content=audio_bytes,
        media_type=media_type,
        headers={"Content-Length": str(len(audio_bytes))},
    )
