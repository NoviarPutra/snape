from fastapi import APIRouter, Depends, HTTPException, status

from app.core.space_config import get_space_config
from app.schemas.material import MaterialResponse
from app.services.obsidian_service import ObsidianService, get_obsidian_service

router = APIRouter(prefix="/materials", tags=["Materials"])

VALID_CATEGORIES: set[str] = {"cheatsheet", "vocab-formal", "slang"}


@router.get("/{space_slug}/{category}", response_model=MaterialResponse)
async def get_learning_material(
    space_slug: str,
    category: str,
    obsidian_service: ObsidianService = Depends(get_obsidian_service),
) -> MaterialResponse:
    try:
        space_config = get_space_config(space_slug)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Space not found",
        )

    if space_config.obsidian_materials_path is None or space_config.cefr_level is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Materials not available for this space",
        )

    if category not in VALID_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Material not yet available",
        )

    content = await obsidian_service.get_learning_materials(
        level=space_config.cefr_level,
        category=category,
    )
    if content is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Material not yet available",
        )

    return MaterialResponse(
        content=content,
        space_slug=space_slug,
        category=category,
    )
