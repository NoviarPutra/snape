import json
from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import TrendingArticle
from app.schemas.trending import TrendingArticleCreate, TrendingArticleUpdate
from app.services.llm_service import BaseLLMService
from app.services.trending_service import (
    build_orchestrator_prompt,
    count_trending_articles,
    create_trending_article,
    delete_trending_article,
    get_trending_article_by_id,
    get_trending_article_by_url,
    list_trending_articles,
    parse_trending_articles_json,
    sync_trending_topics,
    update_trending_article,
    upsert_trending_article,
)


@pytest.mark.asyncio
async def test_create_and_get_trending_article(db_session: AsyncSession) -> None:
    article_in = TrendingArticleCreate(
        category="politics",
        title="Global Summit on AI Safety Reaches Landmark Accord",
        summary=(
            "- Delegates from 40 nations agreed on safety testing standards.\n"
            "- Enforcement framework announced.\n\n"
            "Why It's Trending: First international consensus on frontier AI."
        ),
        source_url="https://example.com/ai-summit-2026",
        published_at=datetime(2026, 9, 3, 12, 0, tzinfo=UTC),
        tags=["ai", "policy", "summit"],
        metadata={"source_name": "Reuters", "viral_score": 89},
    )

    created = await create_trending_article(db_session, article_in)
    assert created.id is not None
    assert created.title == article_in.title
    assert created.category == "politics"

    by_id = await get_trending_article_by_id(db_session, created.id)
    assert by_id is not None
    assert by_id.title == article_in.title

    by_url = await get_trending_article_by_url(db_session, "https://example.com/ai-summit-2026")
    assert by_url is not None
    assert by_url.id == created.id


@pytest.mark.asyncio
async def test_list_and_count_trending_articles(db_session: AsyncSession) -> None:
    # Seed articles across categories
    categories = ["politics", "music", "music", "general"]
    for i, cat in enumerate(categories):
        art = TrendingArticle(
            category=cat,
            title=f"Article {i} in {cat}",
            summary=f"Summary for {i}",
            source_url=f"https://example.com/art-{i}",
            published_at=datetime(2026, 9, i + 1, 0, 0, tzinfo=UTC),
            tags=[cat, f"tag{i}"],
            metadata_={"score": 80 + i},
        )
        db_session.add(art)
    await db_session.commit()

    # Total count
    total = await count_trending_articles(db_session)
    assert total == 4

    # Filtered count
    music_count = await count_trending_articles(db_session, category="music")
    assert music_count == 2

    # List all
    all_arts = await list_trending_articles(db_session, category="all", limit=10)
    assert len(all_arts) == 4
    # Ordered by published_at desc: Article 3 (Sept 4) should be first
    assert all_arts[0].title == "Article 3 in general"

    # List filtered with pagination
    music_arts = await list_trending_articles(db_session, category="music", limit=1, offset=0)
    assert len(music_arts) == 1
    assert music_arts[0].title == "Article 2 in music"


@pytest.mark.asyncio
async def test_upsert_trending_article(db_session: AsyncSession) -> None:
    art_in = TrendingArticleCreate(
        category="creator_trends",
        title="Original Title",
        summary="Original Summary",
        source_url="https://example.com/creator-trend-1",
        tags=["tiktok", "viral"],
        metadata={"viral_score": 75},
    )

    # Initial insert
    created, is_new = await upsert_trending_article(db_session, art_in)
    assert is_new is True
    assert created.title == "Original Title"

    # Update via upsert with same source_url
    updated_in = TrendingArticleCreate(
        category="creator_trends",
        title="Updated Headline After Follow-up",
        summary="Updated Summary with more details",
        source_url="https://example.com/creator-trend-1",
        tags=["tiktok", "viral", "update"],
        metadata={"viral_score": 95},
    )
    updated, is_new2 = await upsert_trending_article(db_session, updated_in)
    assert is_new2 is False
    assert updated.id == created.id
    assert updated.title == "Updated Headline After Follow-up"
    assert updated.metadata_["viral_score"] == 95


@pytest.mark.asyncio
async def test_update_and_delete_trending_article(db_session: AsyncSession) -> None:
    art = TrendingArticle(
        category="general",
        title="Fusion Reactor Sets New Record",
        summary="Details on plasma confinement.",
        source_url="https://example.com/fusion-record",
        tags=["science", "energy"],
        metadata_={"source_name": "Nature"},
    )
    db_session.add(art)
    await db_session.commit()
    await db_session.refresh(art)

    # Update
    updated = await update_trending_article(
        db_session,
        article_id=art.id,
        article_in=TrendingArticleUpdate(title="Fusion Breakthrough 2026"),
    )
    assert updated is not None
    assert updated.title == "Fusion Breakthrough 2026"

    # Delete
    deleted = await delete_trending_article(db_session, article_id=art.id)
    assert deleted is True

    # Not found after delete
    fetched = await get_trending_article_by_id(db_session, article_id=art.id)
    assert fetched is None

    # Delete non-existent
    deleted_again = await delete_trending_article(db_session, article_id=art.id)
    assert deleted_again is False


def test_build_orchestrator_prompt() -> None:
    prompt = build_orchestrator_prompt(category="music", limit=3)
    assert "Hermes News Orchestrator" in prompt
    assert "music" in prompt
    assert "JSON array" in prompt
    assert "3" in prompt


def test_parse_trending_articles_json_clean() -> None:
    raw = json.dumps(
        [
            {
                "category": "music",
                "title": "Surprise Album Drop Shakes Charts",
                "summary": "- Unannounced release hits #1.\n\nWhy It's Trending: Groundbreaking.",
                "source_url": "https://example.com/album-drop",
                "published_at": "2026-09-03T02:00:00Z",
                "tags": ["music", "charts", "album"],
                "metadata": {"source_name": "Billboard", "viral_score": 94},
            }
        ]
    )
    articles = parse_trending_articles_json(raw)
    assert len(articles) == 1
    assert articles[0].category == "music"
    assert articles[0].title == "Surprise Album Drop Shakes Charts"
    assert articles[0].tags == ["music", "charts", "album"]
    assert articles[0].metadata["viral_score"] == 94


def test_parse_trending_articles_json_fenced_markdown() -> None:
    raw = """```json
[
  {
    "category": "creator_trends",
    "title": "New Meme Format Goes Global",
    "summary": "- Originates on Discord.\n\nWhy It's Trending: Universal appeal.",
    "source_url": "https://example.com/meme-trend",
    "published_at": "2026-09-03T03:00:00Z",
    "tags": ["meme", "viral"]
  }
]
```"""
    articles = parse_trending_articles_json(raw)
    assert len(articles) == 1
    assert articles[0].category == "creator_trends"
    assert articles[0].title == "New Meme Format Goes Global"


def test_parse_trending_articles_json_with_text_around_brackets() -> None:
    raw = """Here is the trending news intelligence:

[
  {
    "category": "politics",
    "title": "New Civic Voting Reform Passed",
    "summary": "- Key clauses adopted.\n\nWhy It's Trending: Largest overhaul in decades.",
    "source_url": "https://example.com/civic-reform",
    "tags": ["politics", "reform"]
  }
]

I hope this helps!"""
    articles = parse_trending_articles_json(raw)
    assert len(articles) == 1
    assert articles[0].title == "New Civic Voting Reform Passed"


def test_parse_trending_articles_json_invalid() -> None:
    with pytest.raises(ValueError):
        parse_trending_articles_json("Random gibberish without any JSON")


@pytest.mark.asyncio
async def test_sync_trending_topics(db_session: AsyncSession) -> None:
    mock_llm = AsyncMock(spec=BaseLLMService)
    mock_llm.generate_chat.return_value = json.dumps(
        [
            {
                "category": "general",
                "title": "Deep Space Telescope Discovers Habitable Candidate",
                "summary": "- Water vapor detected.\n\nWhy It's Trending: Habitable exoplanet.",
                "source_url": "https://example.com/space-discovery",
                "published_at": "2026-09-03T04:00:00Z",
                "tags": ["space", "astronomy", "science"],
                "metadata": {"source_name": "NASA/ESA", "viral_score": 97},
            }
        ]
    )

    response = await sync_trending_topics(
        db=db_session,
        category="general",
        limit_per_category=1,
        llm_service=mock_llm,
    )

    assert response.status == "success"
    assert response.synced_count == 1
    assert response.categories == ["general"]

    # Verify saved in db
    saved = await get_trending_article_by_url(db_session, "https://example.com/space-discovery")
    assert saved is not None
    assert saved.title == "Deep Space Telescope Discovers Habitable Candidate"
    assert saved.metadata_["viral_score"] == 97
