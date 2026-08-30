from uuid import UUID

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models import ChatMessage, ChatSession
from app.schemas.message import MessageCreate
from app.schemas.session import SessionCreate, SessionUpdate


async def list_sessions(
    db: AsyncSession, user_id: UUID, limit: int = 50, offset: int = 0
) -> list[ChatSession]:
    """Retrieve chat sessions for a specific user, ordered by most recently updated."""
    stmt = (
        select(ChatSession)
        .where(ChatSession.user_id == user_id)
        .order_by(desc(ChatSession.updated_at))
        .offset(offset)
        .limit(limit)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_session_by_id(
    db: AsyncSession, session_id: UUID, include_messages: bool = False
) -> ChatSession | None:
    """Retrieve a single chat session by ID, optionally loading its messages."""
    stmt = select(ChatSession).where(ChatSession.id == session_id)
    if include_messages:
        stmt = stmt.options(selectinload(ChatSession.messages))
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def create_session(db: AsyncSession, user_id: UUID, session_in: SessionCreate) -> ChatSession:
    """Create a new chat session."""
    session = ChatSession(
        user_id=user_id,
        title=session_in.title or "Casual English Chat",
    )
    db.add(session)
    await db.flush()
    await db.refresh(session)
    return session


async def update_session(
    db: AsyncSession, session_id: UUID, session_in: SessionUpdate
) -> ChatSession | None:
    """Update a chat session's title."""
    session = await get_session_by_id(db, session_id)
    if not session:
        return None
    session.title = session_in.title
    await db.flush()
    await db.refresh(session)
    return session


async def delete_session(db: AsyncSession, session_id: UUID) -> bool:
    """Delete a chat session and its associated messages (cascade)."""
    session = await get_session_by_id(db, session_id)
    if not session:
        return False
    await db.delete(session)
    await db.flush()
    return True


async def add_message(db: AsyncSession, session_id: UUID, message_in: MessageCreate) -> ChatMessage:
    """Add a chat message to an existing session."""
    message = ChatMessage(
        session_id=session_id,
        role=message_in.role,
        content=message_in.content,
        audio_path=message_in.audio_path,
        meta_info=message_in.meta_info,
    )
    db.add(message)
    await db.flush()
    await db.refresh(message)
    return message


async def get_recent_messages(
    db: AsyncSession, session_id: UUID, limit: int = 5
) -> list[ChatMessage]:
    """Retrieve the most recent messages for a session in chronological order."""
    stmt = (
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(desc(ChatMessage.created_at))
        .limit(limit)
    )
    result = await db.execute(stmt)
    messages = list(result.scalars().all())
    messages.reverse()
    return messages
