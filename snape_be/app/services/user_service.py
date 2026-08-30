from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User
from app.schemas.user import UserCreate, UserUpdate

DEFAULT_USERNAME = "learner"


async def get_or_create_default_user(db: AsyncSession) -> User:
    """Retrieve the primary learner user or create the default profile if none exists."""
    stmt = select(User).order_by(User.created_at.asc()).limit(1)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is None:
        user = User(
            username=DEFAULT_USERNAME,
            full_name="English Learner",
            native_language="Indonesian",
            english_level="Intermediate",
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)

    return user


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    """Retrieve a user by their UUID."""
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
    """Retrieve a user by username."""
    stmt = select(User).where(User.username == username)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def create_user(db: AsyncSession, user_in: UserCreate) -> User:
    """Create a new user profile."""
    user = User(
        username=user_in.username,
        full_name=user_in.full_name,
        native_language=user_in.native_language,
        english_level=user_in.english_level,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


async def update_user(db: AsyncSession, user_id: UUID, user_in: UserUpdate) -> User | None:
    """Update an existing user profile."""
    user = await get_user_by_id(db, user_id)
    if not user:
        return None

    if user_in.full_name is not None:
        user.full_name = user_in.full_name
    if user_in.native_language is not None:
        user.native_language = user_in.native_language
    if user_in.english_level is not None:
        user.english_level = user_in.english_level

    await db.flush()
    await db.refresh(user)
    return user
