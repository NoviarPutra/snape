import json
import sys
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

# Ensure scripts directory is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from hermes_news_orchestrator import (  # noqa: E402
    parse_cli_args,
    run_news_orchestrator,
)

from app.services.llm_service import BaseLLMService  # noqa: E402
from app.services.trending_service import get_trending_article_by_url  # noqa: E402


def test_cli_args_defaults() -> None:
    args = parse_cli_args([])
    assert args.category == "all"
    assert args.limit == 5
    assert args.dry_run is False


def test_cli_args_custom() -> None:
    args = parse_cli_args(["--category", "music", "--limit", "10", "--dry-run"])
    assert args.category == "music"
    assert args.limit == 10
    assert args.dry_run is True


@pytest.mark.asyncio
async def test_run_news_orchestrator_dry_run() -> None:
    mock_llm = AsyncMock(spec=BaseLLMService)
    mock_llm.generate_chat.return_value = json.dumps(
        [
            {
                "category": "politics",
                "title": "New Clean Energy Act Passes",
                "summary": "- Clean energy bill approved.\n\nWhy It's Trending: Climate impact.",
                "source_url": "https://example.com/energy-act",
                "published_at": "2026-09-03T01:00:00Z",
                "tags": ["energy", "policy"],
            }
        ]
    )

    articles = await run_news_orchestrator(
        category="politics",
        limit_per_category=1,
        llm_service=mock_llm,
        dry_run=True,
    )

    assert len(articles) == 1
    assert articles[0].title == "New Clean Energy Act Passes"
    assert articles[0].category == "politics"


@pytest.mark.asyncio
async def test_run_news_orchestrator_with_db(db_session: AsyncSession) -> None:
    mock_llm = AsyncMock(spec=BaseLLMService)
    mock_llm.generate_chat.return_value = json.dumps(
        [
            {
                "category": "creator_trends",
                "title": "Interactive Stream Tech Revolutionizes Gaming",
                "summary": "- Viewers control live.\n\nWhy It's Trending: Adopted widely.",
                "source_url": "https://example.com/stream-tech",
                "published_at": "2026-09-03T02:00:00Z",
                "tags": ["gaming", "interactive"],
                "metadata": {"viral_score": 88},
            }
        ]
    )

    articles = await run_news_orchestrator(
        category="creator_trends",
        limit_per_category=1,
        db=db_session,
        llm_service=mock_llm,
        dry_run=False,
    )

    assert len(articles) == 1
    saved = await get_trending_article_by_url(db_session, "https://example.com/stream-tech")
    assert saved is not None
    assert saved.title == "Interactive Stream Tech Revolutionizes Gaming"


@pytest.mark.asyncio
async def test_run_news_orchestrator_invalid_category() -> None:
    with pytest.raises(ValueError):
        await run_news_orchestrator(
            category="invalid_category",
            limit_per_category=1,
            dry_run=True,
        )


@pytest.mark.asyncio
async def test_run_news_orchestrator_handles_llm_failure() -> None:
    mock_llm = AsyncMock(spec=BaseLLMService)
    mock_llm.generate_chat.side_effect = RuntimeError("API Rate Limit Exceeded")

    # Should not raise uncaught exception, but log error and return empty list
    articles = await run_news_orchestrator(
        category="politics",
        limit_per_category=1,
        llm_service=mock_llm,
        dry_run=True,
    )

    assert articles == []
