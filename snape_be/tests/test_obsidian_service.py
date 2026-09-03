from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import pytest

from app.db.models import ChatMessage, User
from app.services.obsidian_service import ObsidianService


@pytest.mark.asyncio
async def test_obsidian_service_topics_and_export(tmp_path: Path) -> None:
    vault_dir = tmp_path / "vault"
    vault_dir.mkdir()
    topics_dir = vault_dir / "Snape" / "Topics"
    topics_dir.mkdir(parents=True)

    # Create a test topic file
    topic_file = topics_dir / "Sample_Topic.md"
    topic_file.write_text(
        "---\ntags:\n  - snape-topic\n---\n# Sample Topic\nLearning Python and Obsidian together.\n"
    )

    service = ObsidianService(vault_path=str(vault_dir), enabled=True)

    # 1. Test load curated topics
    topics = await service.load_curated_topics(limit=5)
    assert len(topics) == 1
    assert "Sample_Topic" in topics[0]
    assert "Learning Python" in topics[0]

    # 2. Test export session journal
    session_id = uuid4()
    user_msg = ChatMessage(
        id=uuid4(),
        session_id=session_id,
        role="user",
        content="I want to learn more about AI.",
        created_at=datetime.now(UTC),
    )
    asst_msg = ChatMessage(
        id=uuid4(),
        session_id=session_id,
        role="assistant",
        content="AI is a fascinating topic! What area interests you most?",
        created_at=datetime.now(UTC),
    )

    file_path = await service.export_session_journal(
        session_id=session_id,
        session_title="AI Discussion",
        messages=[user_msg, asst_msg],
        memories=["Interested in learning AI"],
    )

    assert file_path is not None
    assert file_path.exists()
    content = file_path.read_text()
    assert "snape-session" in content
    assert "AI Discussion" in content
    assert "Interested in learning AI" in content
    assert "I want to learn more about AI." in content

    # 3. Test sync user profile
    user = User(
        id=uuid4(),
        username="learner_dika",
        full_name="Dika",
        native_language="Indonesian",
        english_level="B2 - Upper Intermediate",
    )
    await service.sync_user_profile(user=user, memories=["Works as a software engineer"])
    profile_path = vault_dir / "Snape" / "Profile" / "User.md"
    assert profile_path.exists()
    profile_content = profile_path.read_text()
    assert "Learner Profile: Dika" in profile_content
    assert "Works as a software engineer" in profile_content


@pytest.mark.asyncio
async def test_obsidian_service_get_learning_materials(tmp_path: Path) -> None:
    vault_dir = tmp_path / "vault"
    vault_dir.mkdir()
    materials_b2_dir = vault_dir / "Snape" / "English" / "b2"
    materials_b2_dir.mkdir(parents=True)

    cheatsheet_file = materials_b2_dir / "cheatsheet.md"
    cheatsheet_content = "# B2 Conversational Cheatsheet\n\n- Idiom: Hit the ground running\n"
    cheatsheet_file.write_text(cheatsheet_content, encoding="utf-8")

    service = ObsidianService(vault_path=str(vault_dir), enabled=True)

    # 1. Successful fetch with lowercase level
    content = await service.get_learning_materials(level="b2", category="cheatsheet")
    assert content == cheatsheet_content

    # 2. Successful fetch with uppercase level (case-insensitivity / lowercase resolution)
    content_upper = await service.get_learning_materials(level="B2", category="cheatsheet")
    assert content_upper == cheatsheet_content

    # 3. Non-existent category returns None
    missing_category = await service.get_learning_materials(level="b2", category="slang")
    assert missing_category is None

    # 4. Non-existent level returns None
    missing_level = await service.get_learning_materials(level="a1", category="cheatsheet")
    assert missing_level is None

    # 5. Disabled service returns None
    disabled_service = ObsidianService(vault_path=str(vault_dir), enabled=False)
    assert await disabled_service.get_learning_materials(level="b2", category="cheatsheet") is None

