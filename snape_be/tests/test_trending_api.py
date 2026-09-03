import json
from datetime import UTC, datetime
from unittest.mock import patch
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import TrendingArticle


@pytest.mark.asyncio
async def test_list_trending_empty(client: AsyncClient) -> None:
    response = await client.get("/api/v1/trending")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_list_trending_with_data_and_filtering(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    art1 = TrendingArticle(
        category="politics",
        title="Election Reforms Adopted",
        summary="- Reform bill passes.\n\nWhy It's Trending: Sweeping electoral shifts.",
        source_url="https://example.com/pol-1",
        published_at=datetime(2026, 9, 1, 10, 0, tzinfo=UTC),
        tags=["politics", "election"],
        metadata_={"source_name": "Reuters"},
    )
    art2 = TrendingArticle(
        category="music",
        title="Indie Band Wins Album of the Year",
        summary="- Indie album tops charts.\n\nWhy It's Trending: First self-published win.",
        source_url="https://example.com/music-1",
        published_at=datetime(2026, 9, 2, 10, 0, tzinfo=UTC),
        tags=["music", "indie", "awards"],
        metadata_={"source_name": "Pitchfork"},
    )
    db_session.add_all([art1, art2])
    await db_session.commit()

    # 1. List all
    res_all = await client.get("/api/v1/trending")
    assert res_all.status_code == 200
    items = res_all.json()
    assert len(items) == 2
    # Ordered by published_at desc: art2 first
    assert items[0]["title"] == "Indie Band Wins Album of the Year"
    assert items[0]["category"] == "music"

    # 2. Filter by category 'politics'
    res_pol = await client.get("/api/v1/trending?category=politics")
    assert res_pol.status_code == 200
    pol_items = res_pol.json()
    assert len(pol_items) == 1
    assert pol_items[0]["title"] == "Election Reforms Adopted"

    # 3. Filter with category='all'
    res_all_explicit = await client.get("/api/v1/trending?category=all")
    assert res_all_explicit.status_code == 200
    assert len(res_all_explicit.json()) == 2

    # 4. Invalid category returns 422
    res_invalid = await client.get("/api/v1/trending?category=unknown_category")
    assert res_invalid.status_code == 422

    # 5. Pagination limit and offset
    res_paged = await client.get("/api/v1/trending?limit=1&offset=1")
    assert res_paged.status_code == 200
    paged_items = res_paged.json()
    assert len(paged_items) == 1
    assert paged_items[0]["title"] == "Election Reforms Adopted"


@pytest.mark.asyncio
async def test_get_trending_article_by_id(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    art = TrendingArticle(
        category="creator_trends",
        title="Gaming Streamer Sets World Record",
        summary="- 100-hour marathon stream.\n\nWhy It's Trending: Raised $5M for charity.",
        source_url="https://example.com/streamer-record",
        published_at=datetime(2026, 9, 3, 8, 0, tzinfo=UTC),
        tags=["twitch", "charity", "gaming"],
        metadata_={"source_name": "Dexerto", "viral_score": 91},
    )
    db_session.add(art)
    await db_session.commit()
    await db_session.refresh(art)

    # Success
    res = await client.get(f"/api/v1/trending/{art.id}")
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(art.id)
    assert data["title"] == "Gaming Streamer Sets World Record"
    assert data["metadata"]["viral_score"] == 91

    # Not Found
    random_id = uuid4()
    res_404 = await client.get(f"/api/v1/trending/{random_id}")
    assert res_404.status_code == 404

    # Invalid UUID
    res_422 = await client.get("/api/v1/trending/not-a-uuid")
    assert res_422.status_code == 422


@pytest.mark.asyncio
async def test_post_trending_sync(
    client: AsyncClient,
) -> None:
    mock_articles_json = json.dumps(
        [
            {
                "category": "music",
                "title": "Global Tour Sells Out in Minutes",
                "summary": "- 2 million tickets sold.\n\nWhy It's Trending: Historic demand.",
                "source_url": "https://example.com/global-tour-2026",
                "published_at": "2026-09-03T05:00:00Z",
                "tags": ["music", "concert"],
                "metadata": {"source_name": "Billboard", "viral_score": 96},
            }
        ]
    )

    with patch(
        "app.services.llm_service.OmniRouteLLMService.generate_chat",
        return_value=mock_articles_json,
    ):
        res = await client.post(
            "/api/v1/trending/sync",
            json={"category": "music", "limit_per_category": 1},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["synced_count"] == 1
        assert data["categories"] == ["music"]

    # Verify article is now retrievable via GET /api/v1/trending
    get_res = await client.get("/api/v1/trending?category=music")
    assert get_res.status_code == 200
    items = get_res.json()
    assert len(items) == 1
    assert items[0]["title"] == "Global Tour Sells Out in Minutes"


@pytest.mark.asyncio
async def test_post_trending_sync_invalid_category(
    client: AsyncClient,
) -> None:
    res = await client.post(
        "/api/v1/trending/sync",
        json={"category": "invalid_cat"},
    )
    assert res.status_code == 422
