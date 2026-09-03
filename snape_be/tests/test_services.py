import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.message import MessageCreate
from app.schemas.session import SessionCreate, SessionUpdate
from app.schemas.user import UserCreate, UserUpdate
from app.services import session_service, user_service


@pytest.mark.asyncio
async def test_user_service_operations(db_session: AsyncSession) -> None:
    # 1. get_or_create_default_user when empty
    default_user = await user_service.get_or_create_default_user(db_session)
    assert default_user.username == "learner"

    # 2. get_or_create_default_user when existing
    same_user = await user_service.get_or_create_default_user(db_session)
    assert same_user.id == default_user.id

    # 3. get_user_by_id
    fetched = await user_service.get_user_by_id(db_session, default_user.id)
    assert fetched is not None
    assert fetched.id == default_user.id

    # 4. get_user_by_username
    by_name = await user_service.get_user_by_username(db_session, "learner")
    assert by_name is not None
    assert by_name.id == default_user.id

    # 5. create_user
    new_user = await user_service.create_user(
        db_session,
        UserCreate(username="alice", full_name="Alice Wonder", english_level="Beginner"),
    )
    assert new_user.username == "alice"
    assert new_user.english_level == "Beginner"

    # 6. update_user
    updated = await user_service.update_user(
        db_session,
        new_user.id,
        UserUpdate(full_name="Alice In Wonderland", english_level="Advanced"),
    )
    assert updated is not None
    assert updated.full_name == "Alice In Wonderland"
    assert updated.english_level == "Advanced"


@pytest.mark.asyncio
async def test_session_service_operations(db_session: AsyncSession) -> None:
    user = await user_service.get_or_create_default_user(db_session)

    # 1. Create session with explicit title and default space_slug
    session = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(title="Daily English Practice"),
    )
    assert session.id is not None
    assert session.title == "Daily English Practice"
    assert session.space_slug == "english_b2"

    # Create session with omitted title (should default to Space display name)
    session_default_b2 = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(),
    )
    assert session_default_b2.title == "B2 – Conversational"
    assert session_default_b2.space_slug == "english_b2"

    # Create session with space_slug="tech" and omitted title
    session_tech = await session_service.create_session(
        db_session,
        user_id=user.id,
        session_in=SessionCreate(space_slug="tech"),
    )
    assert session_tech.title == "Teknologi"
    assert session_tech.space_slug == "tech"

    # 2. List sessions (all, and filtered by space_slug)
    all_sessions = await session_service.list_sessions(db_session, user_id=user.id)
    assert len(all_sessions) == 3

    b2_sessions = await session_service.list_sessions(
        db_session, user_id=user.id, space_slug="english_b2"
    )
    assert len(b2_sessions) == 2
    assert all(s.space_slug == "english_b2" for s in b2_sessions)

    tech_sessions = await session_service.list_sessions(
        db_session, user_id=user.id, space_slug="tech"
    )
    assert len(tech_sessions) == 1
    assert tech_sessions[0].id == session_tech.id
    assert tech_sessions[0].space_slug == "tech"

    psych_sessions = await session_service.list_sessions(
        db_session, user_id=user.id, space_slug="psychology"
    )
    assert len(psych_sessions) == 0

    # 3. Add messages
    msg1 = await session_service.add_message(
        db_session,
        session_id=session.id,
        message_in=MessageCreate(role="user", content="Hello!"),
    )
    msg2 = await session_service.add_message(
        db_session,
        session_id=session.id,
        message_in=MessageCreate(role="assistant", content="Hi there! How can I help?"),
    )
    assert msg1.id is not None
    assert msg2.id is not None

    # 4. Get session with messages and test get_recent_messages
    detailed = await session_service.get_session_by_id(
        db_session, session.id, include_messages=True
    )
    assert detailed is not None
    assert len(detailed.messages) == 2
    assert detailed.messages[0].content == "Hello!"
    assert detailed.messages[1].content == "Hi there! How can I help?"

    recent = await session_service.get_recent_messages(db_session, session.id, limit=5)
    assert len(recent) == 2
    assert recent[0].content == "Hello!"
    assert recent[1].content == "Hi there! How can I help?"

    # 5. Update session
    updated = await session_service.update_session(
        db_session,
        session.id,
        SessionUpdate(title="Revised Session Title"),
    )
    assert updated is not None
    assert updated.title == "Revised Session Title"

    # 6. Test count_user_messages
    count_before = await session_service.count_user_messages(db_session, session.id)
    assert count_before == 1

    await session_service.add_message(
        db_session,
        session_id=session.id,
        message_in=MessageCreate(role="user", content="Second user question"),
    )
    await session_service.add_message(
        db_session,
        session_id=session.id,
        message_in=MessageCreate(role="assistant", content="Second assistant response"),
    )
    count_after = await session_service.count_user_messages(db_session, session.id)
    assert count_after == 2

    # 7. Delete session
    deleted = await session_service.delete_session(db_session, session.id)
    assert deleted is True

    # 8. Confirm deletion
    not_found = await session_service.get_session_by_id(db_session, session.id)
    assert not_found is None
