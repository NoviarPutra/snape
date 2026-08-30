from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.session import (
    SessionCreate,
    SessionDetailResponse,
    SessionResponse,
    SessionUpdate,
)
from app.services import session_service, user_service

router = APIRouter(prefix="/sessions", tags=["Sessions"])


@router.get("", response_model=list[SessionResponse])
async def list_user_sessions(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
) -> list[SessionResponse]:
    """Retrieve all chat sessions for the current user."""
    user = await user_service.get_or_create_default_user(db)
    sessions = await session_service.list_sessions(db, user_id=user.id, limit=limit, offset=offset)
    return [SessionResponse.model_validate(s) for s in sessions]


@router.post("", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_chat_session(
    session_in: SessionCreate,
    db: AsyncSession = Depends(get_db),
) -> SessionResponse:
    """Create a new chat session for the current user."""
    user = await user_service.get_or_create_default_user(db)
    session = await session_service.create_session(db, user_id=user.id, session_in=session_in)
    return SessionResponse.model_validate(session)


@router.get("/{session_id}", response_model=SessionDetailResponse)
async def get_session_detail(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SessionDetailResponse:
    """Retrieve a single session along with its full message history."""
    session = await session_service.get_session_by_id(
        db, session_id=session_id, include_messages=True
    )
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return SessionDetailResponse.model_validate(session)


@router.patch("/{session_id}", response_model=SessionResponse)
async def update_session_title(
    session_id: UUID,
    session_in: SessionUpdate,
    db: AsyncSession = Depends(get_db),
) -> SessionResponse:
    """Update a session's title."""
    updated = await session_service.update_session(db, session_id=session_id, session_in=session_in)
    if not updated:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
    return SessionResponse.model_validate(updated)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session_endpoint(
    session_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete a session and all its messages."""
    deleted = await session_service.delete_session(db, session_id=session_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")
