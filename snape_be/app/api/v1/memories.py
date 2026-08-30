from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.memory import MemoryResponse
from app.services import user_service
from app.services.memory_service import MemoryService, get_memory_service

router = APIRouter(prefix="/memories", tags=["Memories"])


@router.get("", response_model=list[MemoryResponse])
async def list_memories(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    category: str | None = Query(default=None, description="Filter by category"),
    db: AsyncSession = Depends(get_db),
    memory_service: MemoryService = Depends(get_memory_service),
) -> list[MemoryResponse]:
    """Retrieve long-term memories for the current user."""
    user = await user_service.get_or_create_default_user(db)
    memories = await memory_service.get_memories(
        db=db,
        user_id=user.id,
        limit=limit,
        offset=offset,
        category=category,
    )
    return [MemoryResponse.model_validate(m) for m in memories]


@router.delete("/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_memory_endpoint(
    memory_id: UUID,
    db: AsyncSession = Depends(get_db),
    memory_service: MemoryService = Depends(get_memory_service),
) -> None:
    """Delete a specific memory by its ID."""
    user = await user_service.get_or_create_default_user(db)
    deleted = await memory_service.delete_memory(
        db=db,
        memory_id=memory_id,
        user_id=user.id,
    )
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Memory not found",
        )
    await db.commit()
