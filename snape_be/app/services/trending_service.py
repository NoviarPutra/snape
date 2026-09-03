import json
import logging
import re
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import TrendingArticle
from app.schemas.trending import (
    VALID_TRENDING_CATEGORIES,
    TrendingArticleCreate,
    TrendingArticleUpdate,
    TrendingSyncResponse,
)
from app.services.llm_service import BaseLLMService, OmniRouteLLMService

logger = logging.getLogger("trending_service")

CATEGORY_TOPIC_GUIDES: dict[str, dict[str, str]] = {
    "politics": {
        "label": "Politics & Geopolitics",
        "scope": "Major policy shifts, international relations, elections, civic debate",
        "sample_sources": "Reuters, AP News, BBC, Politico",
    },
    "general": {
        "label": "General News & Science",
        "scope": "Breakthrough technologies, space, environment, major events",
        "sample_sources": "Nature, TechCrunch, The Verge, BBC",
    },
    "music": {
        "label": "Music & Entertainment",
        "scope": "Album drops, global concert tours, chart hits, viral tracks",
        "sample_sources": "Billboard, Pitchfork, Rolling Stone, NME",
    },
    "creator_trends": {
        "label": "Creator Trends & Internet Culture",
        "scope": "Viral memes, YouTube/TikTok phenomena, streaming culture",
        "sample_sources": "Dexerto, KnowYourMeme, Polygon, Social Trends",
    },
}


# Database CRUD Operations


async def list_trending_articles(
    db: AsyncSession,
    category: str | None = None,
    limit: int = 20,
    offset: int = 0,
) -> list[TrendingArticle]:
    """Retrieve trending articles ordered by published_at with optional category filter."""
    stmt = select(TrendingArticle)
    if category is not None and category.strip().lower() != "all":
        stmt = stmt.where(TrendingArticle.category == category.strip().lower())
    stmt = stmt.order_by(desc(TrendingArticle.published_at), desc(TrendingArticle.created_at))
    stmt = stmt.offset(offset).limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_trending_article_by_id(
    db: AsyncSession,
    article_id: UUID,
) -> TrendingArticle | None:
    """Retrieve a single trending article by its unique ID."""
    stmt = select(TrendingArticle).where(TrendingArticle.id == article_id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_trending_article_by_url(
    db: AsyncSession,
    source_url: str,
) -> TrendingArticle | None:
    """Retrieve a trending article by its source URL."""
    stmt = select(TrendingArticle).where(TrendingArticle.source_url == source_url)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def count_trending_articles(
    db: AsyncSession,
    category: str | None = None,
) -> int:
    """Count total trending articles matching an optional category filter."""
    stmt = select(func.count(TrendingArticle.id))
    if category is not None and category.strip().lower() != "all":
        stmt = stmt.where(TrendingArticle.category == category.strip().lower())
    result = await db.execute(stmt)
    return result.scalar_one() or 0


async def create_trending_article(
    db: AsyncSession,
    article_in: TrendingArticleCreate,
) -> TrendingArticle:
    """Create a new trending article record."""
    published_at = article_in.published_at or datetime.now(UTC)
    article = TrendingArticle(
        category=article_in.category,
        title=article_in.title.strip(),
        summary=article_in.summary.strip(),
        source_url=article_in.source_url.strip(),
        published_at=published_at,
        tags=article_in.tags,
        metadata_=article_in.metadata,
    )
    db.add(article)
    await db.commit()
    await db.refresh(article)
    return article


async def upsert_trending_article(
    db: AsyncSession,
    article_in: TrendingArticleCreate,
) -> tuple[TrendingArticle, bool]:
    """Upsert trending article by source_url.

    Returns tuple of (article, is_created).
    """
    existing = await get_trending_article_by_url(db, source_url=article_in.source_url.strip())
    if existing:
        existing.category = article_in.category
        existing.title = article_in.title.strip()
        existing.summary = article_in.summary.strip()
        if article_in.published_at:
            existing.published_at = article_in.published_at
        existing.tags = article_in.tags
        existing.metadata_ = article_in.metadata
        await db.commit()
        await db.refresh(existing)
        return existing, False

    new_article = await create_trending_article(db, article_in=article_in)
    return new_article, True


async def update_trending_article(
    db: AsyncSession,
    article_id: UUID,
    article_in: TrendingArticleUpdate,
) -> TrendingArticle | None:
    """Update specific fields of an existing trending article."""
    article = await get_trending_article_by_id(db, article_id=article_id)
    if not article:
        return None

    if article_in.title is not None:
        article.title = article_in.title.strip()
    if article_in.summary is not None:
        article.summary = article_in.summary.strip()
    if article_in.source_url is not None:
        article.source_url = article_in.source_url.strip()
    if article_in.published_at is not None:
        article.published_at = article_in.published_at
    if article_in.tags is not None:
        article.tags = article_in.tags
    if article_in.metadata is not None:
        article.metadata_ = article_in.metadata

    await db.commit()
    await db.refresh(article)
    return article


async def delete_trending_article(
    db: AsyncSession,
    article_id: UUID,
) -> bool:
    """Delete a trending article by its ID."""
    article = await get_trending_article_by_id(db, article_id=article_id)
    if not article:
        return False
    await db.delete(article)
    await db.commit()
    return True


# Orchestrator & LLM Synthesis


def build_orchestrator_prompt(category: str, limit: int = 5) -> str:
    """Build the system prompt for Hermes News Orchestrator to generate trending items."""
    guide = CATEGORY_TOPIC_GUIDES.get(
        category,
        {
            "label": category.title(),
            "scope": "Current viral trends and verified news",
            "sample_sources": "Global News Outlets",
        },
    )
    now_iso = datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

    return f"""You are Hermes News Orchestrator (Agent 2) for the Snape learning ecosystem.

Generate {limit} currently trending topics for '{category}' ({guide["label"]}).
Focus on: {guide["scope"]}.
Reference authentic or realistic source outlets (e.g. {guide["sample_sources"]}).

For each article, you MUST generate:
1. "category": "{category}"
2. "title": Engaging headline.
3. "summary": Concise bulleted digest (>= 2 bullets) plus a "Why It's Trending" rationale.
4. "source_url": A valid HTTPS source URL.
5. "published_at": ISO-8601 UTC timestamp string (e.g. "{now_iso}").
6. "tags": Array of 3-5 relevant lowercase keyword strings.
7. "metadata": Object with "source_name" (str), "viral_score" (int), "discussion_hooks" (list[str]).

OUTPUT FORMAT:
Output ONLY a strict JSON array containing the {limit} objects without markdown fences.
"""


def parse_trending_articles_json(raw_text: str) -> list[TrendingArticleCreate]:
    """Parse raw LLM response into a list of validated TrendingArticleCreate objects."""
    cleaned = raw_text.strip()
    # Strip markdown fences if present
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = cleaned.strip()

    try:
        data = json.loads(cleaned, strict=False)
    except json.JSONDecodeError as exc:
        logger.warning(f"Failed to parse JSON directly: {exc}. Attempting bracket extraction.")
        # Attempt to extract JSON array
        match = re.search(r"\[\s*\{.*\}\s*\]", cleaned, re.DOTALL)
        if match:
            try:
                data = json.loads(match.group(0), strict=False)
            except json.JSONDecodeError:
                raise ValueError(
                    f"Could not parse valid JSON from LLM output: {cleaned[:200]}"
                ) from exc
        else:
            raise ValueError(f"No JSON array found in LLM output: {cleaned[:200]}") from exc

    if not isinstance(data, list):
        if isinstance(data, dict):
            data = [data]
        else:
            raise ValueError("Expected JSON array of trending articles")

    articles: list[TrendingArticleCreate] = []
    for item in data:
        if not isinstance(item, dict):
            continue
        try:
            # Normalize published_at if string provided
            published_at = item.get("published_at")
            parsed_dt = None
            if published_at:
                if isinstance(published_at, str):
                    try:
                        parsed_dt = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
                    except ValueError:
                        parsed_dt = datetime.now(UTC)
                elif isinstance(published_at, datetime):
                    parsed_dt = published_at
            if parsed_dt is None:
                parsed_dt = datetime.now(UTC)

            category = str(item.get("category", "general")).strip().lower()
            if category not in VALID_TRENDING_CATEGORIES:
                category = "general"

            title = str(item.get("title", "")).strip()
            summary = str(item.get("summary", "")).strip()
            source_url = str(item.get("source_url", "")).strip()
            if not source_url:
                source_url = f"https://news.example.com/{category}/{abs(hash(title))}"

            tags = item.get("tags")
            if not isinstance(tags, list):
                tags = [str(tags)] if tags else []
            tags = [str(t).strip().lower() for t in tags if str(t).strip()]

            metadata = item.get("metadata")
            if not isinstance(metadata, dict):
                metadata = {}

            if title and summary:
                articles.append(
                    TrendingArticleCreate(
                        category=category,
                        title=title,
                        summary=summary,
                        source_url=source_url,
                        published_at=parsed_dt,
                        tags=tags,
                        metadata=metadata,
                    )
                )
        except Exception as err:
            logger.warning(f"Skipping malformed article item: {err}")

    return articles


async def sync_trending_topics(
    db: AsyncSession,
    category: str | None = None,
    limit_per_category: int = 5,
    llm_service: BaseLLMService | None = None,
) -> TrendingSyncResponse:
    """Discover, synthesize, and persist trending topics across requested categories."""
    llm = llm_service or OmniRouteLLMService()

    categories_to_sync: list[str]
    if category is None or category.strip().lower() == "all":
        categories_to_sync = list(VALID_TRENDING_CATEGORIES)
    else:
        cat_clean = category.strip().lower()
        if cat_clean not in VALID_TRENDING_CATEGORIES:
            valid_cats = list(VALID_TRENDING_CATEGORIES)
            raise ValueError(
                f"Invalid category '{category}'. Valid categories: {valid_cats}"
            )
        categories_to_sync = [cat_clean]

    total_synced = 0
    errors: list[str] = []

    for cat in categories_to_sync:
        try:
            prompt = build_orchestrator_prompt(category=cat, limit=limit_per_category)
            response_text = await llm.generate_chat(
                system_instruction=prompt,
                contents=[
                    {
                        "role": "user",
                        "content": f"Sync top trending topics for {cat} as JSON.",
                    }
                ],
                temperature=0.3,
                response_format_json=True,
            )
            article_creates = parse_trending_articles_json(response_text)
            for art_in in article_creates:
                await upsert_trending_article(db, article_in=art_in)
                total_synced += 1
        except Exception as exc:
            logger.error(f"Error syncing category '{cat}': {exc}", exc_info=True)
            errors.append(f"{cat}: {str(exc)}")

    status_str = "success" if not errors else ("partial" if total_synced > 0 else "failed")
    if not errors:
        msg = f"Synchronized {total_synced} articles across {len(categories_to_sync)} categories."
    else:
        err_detail = "; ".join(errors)
        msg = f"Sync partial/failed. Synced {total_synced} articles. Errors: {err_detail}"

    return TrendingSyncResponse(
        status=status_str,
        synced_count=total_synced,
        categories=categories_to_sync,
        message=msg,
    )
