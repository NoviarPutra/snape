from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.user import UserResponse, UserUpdate
from app.services import user_service

router = APIRouter(prefix="/user", tags=["User"])


@router.get("", response_model=UserResponse)
async def get_current_user(db: AsyncSession = Depends(get_db)) -> UserResponse:
    """Retrieve the primary learner's profile (creating default if first time)."""
    user = await user_service.get_or_create_default_user(db)
    return UserResponse.model_validate(user)


@router.patch("", response_model=UserResponse)
async def update_current_user(
    user_in: UserUpdate,
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Update the primary learner's profile."""
    current_user = await user_service.get_or_create_default_user(db)
    updated = await user_service.update_user(db, current_user.id, user_in)
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserResponse.model_validate(updated)
