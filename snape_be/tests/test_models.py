import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ChatMessage, ChatSession, User, UserMemory


@pytest.mark.asyncio
async def test_user_creation_and_relations(db_session: AsyncSession) -> None:
    """Test User creation and relationship cascading."""
    user = User(
        username="john_doe",
        full_name="John Doe",
        native_language="Indonesian",
        english_level="Advanced",
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    assert user.id is not None
    assert user.username == "john_doe"
    assert user.native_language == "Indonesian"

    # Create ChatSession
    session = ChatSession(
        user_id=user.id,
        title="Travel in London",
    )
    db_session.add(session)
    await db_session.commit()
    await db_session.refresh(session)

    assert session.id is not None
    assert session.user_id == user.id
    assert session.space_slug == "english_b2"

    # Create ChatSession with explicit space_slug
    tech_session = ChatSession(
        user_id=user.id,
        title="Tech Discussion",
        space_slug="tech",
    )
    db_session.add(tech_session)
    await db_session.commit()
    await db_session.refresh(tech_session)

    assert tech_session.id is not None
    assert tech_session.space_slug == "tech"

    # Create ChatMessage
    message = ChatMessage(
        session_id=session.id,
        role="user",
        content="I want to visit Big Ben.",
        meta_info={"topic": "travel"},
    )
    db_session.add(message)
    await db_session.commit()
    await db_session.refresh(message)

    assert message.id is not None
    assert message.session_id == session.id
    assert message.role == "user"

    # Create UserMemory with 768-dim dummy vector
    dummy_vector = [0.01 * (i % 10) for i in range(768)]
    memory = UserMemory(
        user_id=user.id,
        category="goal",
        content="Wants to travel to London next summer.",
        embedding=dummy_vector,
    )
    db_session.add(memory)
    await db_session.commit()
    await db_session.refresh(memory)

    assert memory.id is not None
    assert memory.category == "goal"
    assert len(memory.embedding) == 768
