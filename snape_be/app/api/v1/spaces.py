from fastapi import APIRouter

from app.core.space_config import SPACE_REGISTRY
from app.schemas.space import SpacePublicResponse

router = APIRouter(prefix="/spaces", tags=["Spaces"])


@router.get("", response_model=list[SpacePublicResponse])
async def list_spaces() -> list[SpacePublicResponse]:
    """List all available discussion spaces and their capabilities."""
    return [
        SpacePublicResponse(
            slug=cfg.slug,
            display_name=cfg.display_name,
            cefr_level=cfg.cefr_level,
            tts_enabled=cfg.tts_enabled,
            voice_call_enabled=cfg.voice_call_enabled,
            starter_prompts=list(cfg.starter_prompts),
        )
        for cfg in SPACE_REGISTRY.values()
    ]
