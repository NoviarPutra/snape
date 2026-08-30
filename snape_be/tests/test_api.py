import pytest
from httpx import AsyncClient


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
    # 1. Create a session
    create_res = await client.post(
        "/api/v1/sessions",
        json={"title": "Weekend Practice"},
    )
    assert create_res.status_code == 201
    session_data = create_res.json()
    session_id = session_data["id"]
    assert session_data["title"] == "Weekend Practice"

    # 2. List sessions
    list_res = await client.get("/api/v1/sessions")
    assert list_res.status_code == 200
    sessions = list_res.json()
    assert len(sessions) >= 1
    assert any(s["id"] == session_id for s in sessions)

    # 3. Get session detail
    detail_res = await client.get(f"/api/v1/sessions/{session_id}")
    assert detail_res.status_code == 200
    detail = detail_res.json()
    assert detail["id"] == session_id
    assert detail["title"] == "Weekend Practice"
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
