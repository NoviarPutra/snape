from pathlib import Path
from uuid import UUID

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.memory import MemoryCreate
from app.services.memory_service import get_memory_service
from app.services.obsidian_service import ObsidianService, get_obsidian_service


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient) -> None:
    """Test health check endpoint."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert "version" in data
    assert "database_connected" in data
    assert "timestamp" in data
    assert data["version"] == "0.1.0"
    assert data["database_connected"] is True


@pytest.mark.asyncio
async def test_user_endpoints(client: AsyncClient) -> None:
    """Test get and update current user."""
    # 1. Get user (auto creates default user)
    get_res = await client.get("/api/v1/user")
    assert get_res.status_code == 200
    user_data = get_res.json()
    assert user_data["username"] == "learner"
    assert user_data["native_language"] == "Indonesian"
    assert user_data["english_level"] == "Intermediate"

    # 2. Update user profile
    update_res = await client.patch(
        "/api/v1/user",
        json={
            "full_name": "Budi",
            "english_level": "Advanced",
        },
    )
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["full_name"] == "Budi"
    assert updated_data["english_level"] == "Advanced"
    assert updated_data["native_language"] == "Indonesian"


@pytest.mark.asyncio
async def test_session_lifecycle_endpoints(client: AsyncClient) -> None:
    """Test session CRUD REST endpoints."""
    # 1. Create a session with default space_slug (english_b2)
    create_res = await client.post(
        "/api/v1/sessions",
        json={"title": "Weekend Practice"},
    )
    assert create_res.status_code == 201
    session_data = create_res.json()
    session_id = session_data["id"]
    assert session_data["title"] == "Weekend Practice"
    assert session_data["space_slug"] == "english_b2"

    # Create a session with explicit space_slug and omitted title
    create_tech_res = await client.post(
        "/api/v1/sessions",
        json={"space_slug": "tech"},
    )
    assert create_tech_res.status_code == 201
    tech_data = create_tech_res.json()
    assert tech_data["title"] == "Teknologi"
    assert tech_data["space_slug"] == "tech"

    # 2. List sessions without filter
    list_res = await client.get("/api/v1/sessions")
    assert list_res.status_code == 200
    sessions = list_res.json()
    assert len(sessions) >= 2
    assert any(s["id"] == session_id for s in sessions)
    assert any(s["id"] == tech_data["id"] for s in sessions)

    # List sessions filtered by space_slug=tech
    list_tech_res = await client.get("/api/v1/sessions?space_slug=tech")
    assert list_tech_res.status_code == 200
    tech_sessions = list_tech_res.json()
    assert len(tech_sessions) == 1
    assert tech_sessions[0]["id"] == tech_data["id"]
    assert tech_sessions[0]["space_slug"] == "tech"

    # List sessions filtered by space_slug=english_b2
    list_b2_res = await client.get("/api/v1/sessions?space_slug=english_b2")
    assert list_b2_res.status_code == 200
    b2_sessions = list_b2_res.json()
    assert all(s["space_slug"] == "english_b2" for s in b2_sessions)

    # 3. Get session detail
    detail_res = await client.get(f"/api/v1/sessions/{session_id}")
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["id"] == session_id
    assert detail["title"] == "Weekend Practice"
    assert detail["space_slug"] == "english_b2"
    assert "messages" in detail
    assert isinstance(detail["messages"], list)

    # 4. Update session title
    patch_res = await client.patch(
        f"/api/v1/sessions/{session_id}",
        json={"title": "Job Interview Prep"},
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["title"] == "Job Interview Prep"

    # 5. Delete session
    delete_res = await client.delete(f"/api/v1/sessions/{session_id}")
    assert delete_res.status_code == 204

    # 6. Verify deleted session gives 404
    get_deleted = await client.get(f"/api/v1/sessions/{session_id}")
    assert get_deleted.status_code == 404


@pytest.mark.asyncio
async def test_create_session_unknown_space_slug_returns_422(client: AsyncClient) -> None:
    """Test session creation fails with 422 for invalid space_slug."""
    response = await client.post(
        "/api/v1/sessions",
        json={"space_slug": "invalid_space_xyz"},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_memory_endpoints(client: AsyncClient, db_session: AsyncSession) -> None:
    """Test GET /api/v1/memories and DELETE /api/v1/memories/{id} endpoints."""
    # 1. Initially empty memories list
    list_res = await client.get("/api/v1/memories")
    assert list_res.status_code == 200
    assert list_res.json() == []

    # 2. Add memories via memory service directly
    user_res = await client.get("/api/v1/user")
    assert user_res.status_code == 200
    user_id = UUID(user_res.json()["id"])

    mem_service = get_memory_service()
    emb1 = await mem_service.embedding_service.generate_embedding("Enjoys hiking on mountains")
    emb2 = await mem_service.embedding_service.generate_embedding(
        "Wants to pass IELTS with band 7.5"
    )

    mem1 = await mem_service.create_memory(
        db_session,
        user_id=user_id,
        memory_in=MemoryCreate(
            user_id=user_id,
            category="preference",
            content="Enjoys hiking on mountains",
            embedding=emb1,
        ),
    )
    mem2 = await mem_service.create_memory(
        db_session,
        user_id=user_id,
        memory_in=MemoryCreate(
            user_id=user_id,
            category="goal",
            content="Wants to pass IELTS with band 7.5",
            embedding=emb2,
        ),
    )
    await db_session.commit()
    assert mem1 is not None
    assert mem2 is not None

    # 3. Retrieve memories via GET endpoint
    list_res2 = await client.get("/api/v1/memories")
    assert list_res2.status_code == 200
    memories = list_res2.json()
    assert len(memories) == 2

    # 4. Filter by category
    goal_res = await client.get("/api/v1/memories?category=goal")
    assert goal_res.status_code == 200
    goals = goal_res.json()
    assert len(goals) == 1
    assert goals[0]["content"] == "Wants to pass IELTS with band 7.5"
    assert goals[0]["category"] == "goal"

    # 5. Delete a memory
    del_res = await client.delete(f"/api/v1/memories/{mem1.id}")
    assert del_res.status_code == 204

    # 6. Verify only 1 memory left
    list_res3 = await client.get("/api/v1/memories")
    assert list_res3.status_code == 200
    remaining = list_res3.json()
    assert len(remaining) == 1
    assert remaining[0]["id"] == str(mem2.id)

    # 7. Deleting already deleted / nonexistent memory returns 404
    del_res_404 = await client.delete(f"/api/v1/memories/{mem1.id}")
    assert del_res_404.status_code == 404


@pytest.mark.asyncio
async def test_materials_endpoints(client: AsyncClient, tmp_path: Path) -> None:
    vault_dir = tmp_path / "vault"
    vault_dir.mkdir()
    b2_dir = vault_dir / "Snape" / "English" / "b2"
    b2_dir.mkdir(parents=True)
    cheatsheet_file = b2_dir / "cheatsheet.md"
    cheatsheet_content = "# B2 Cheatsheet Content\n\nConversational phrases."
    cheatsheet_file.write_text(cheatsheet_content, encoding="utf-8")

    test_obsidian = ObsidianService(vault_path=str(vault_dir), enabled=True)

    transport = client._transport
    assert isinstance(transport, ASGITransport)
    app = transport.app
    assert isinstance(app, FastAPI)
    app.dependency_overrides[get_obsidian_service] = lambda: test_obsidian

    try:
        # 1. Valid English space with existing material
        res = await client.get("/api/v1/materials/english_b2/cheatsheet")
        assert res.status_code == 200
        data = res.json()
        assert data["content"] == cheatsheet_content
        assert data["space_slug"] == "english_b2"
        assert data["category"] == "cheatsheet"

        # 2. Non-English space returns 404 with specific detail
        tech_res = await client.get("/api/v1/materials/tech/cheatsheet")
        assert tech_res.status_code == 404
        assert tech_res.json()["detail"] == "Materials not available for this space"

        # 3. Valid space but category file not yet created returns 404
        missing_res = await client.get("/api/v1/materials/english_b2/vocab-formal")
        assert missing_res.status_code == 404
        assert missing_res.json()["detail"] == "Material not yet available"

        # 4. Unknown space slug returns 404
        unknown_res = await client.get("/api/v1/materials/nonexistent_space/cheatsheet")
        assert unknown_res.status_code == 404

        # 5. Invalid category returns 404
        invalid_cat_res = await client.get("/api/v1/materials/english_b2/unknown_category")
        assert invalid_cat_res.status_code == 404
        assert invalid_cat_res.json()["detail"] == "Material not yet available"
    finally:
        app.dependency_overrides.pop(get_obsidian_service, None)

