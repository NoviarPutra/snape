#!/usr/bin/env python3
"""Hermes News Orchestrator (Agent 2) — Autonomous Internet Intelligence & Trend Aggregator.

Discovers, summarizes, and categorizes trending topics across 4 domains:
(politics, general, music, creator_trends) into public.trending_articles in Supabase PostgreSQL.
"""

import argparse
import asyncio
import logging
import sys
from pathlib import Path
from typing import Any

# Ensure backend root is on sys.path when executed directly
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import async_session_factory  # noqa: E402
from app.schemas.trending import (  # noqa: E402
    VALID_TRENDING_CATEGORIES,
    TrendingArticleCreate,
)
from app.services.llm_service import BaseLLMService, OmniRouteLLMService  # noqa: E402
from app.services.trending_service import (  # noqa: E402
    build_orchestrator_prompt,
    parse_trending_articles_json,
    upsert_trending_article,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger("hermes_news_orchestrator")


def parse_cli_args(args: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments for the Hermes News Orchestrator."""
    parser = argparse.ArgumentParser(
        description="Hermes News Orchestrator: Real-time trend discovery and aggregation agent.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--category",
        "-c",
        type=str,
        default="all",
        choices=[*VALID_TRENDING_CATEGORIES, "all"],
        help="Target category ('politics', 'general', 'music', 'creator_trends', or 'all').",
    )
    parser.add_argument(
        "--limit",
        "-l",
        type=int,
        default=5,
        help="Number of trending articles to curate per category (1–20).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run discovery and synthesis without persisting to the database.",
    )
    return parser.parse_args(args)


async def run_news_orchestrator(
    category: str = "all",
    limit_per_category: int = 5,
    db: Any | None = None,
    llm_service: BaseLLMService | None = None,
    dry_run: bool = False,
) -> list[TrendingArticleCreate]:
    """Execute trending news intelligence curation across requested categories."""
    llm = llm_service or OmniRouteLLMService()

    categories_to_run: list[str]
    if category == "all":
        categories_to_run = list(VALID_TRENDING_CATEGORIES)
    else:
        cat_clean = category.strip().lower()
        if cat_clean not in VALID_TRENDING_CATEGORIES:
            valid_cats = list(VALID_TRENDING_CATEGORIES)
            raise ValueError(
                f"Invalid category '{category}'. Valid categories: {valid_cats} or 'all'"
            )
        categories_to_run = [cat_clean]

    all_articles: list[TrendingArticleCreate] = []

    for cat in categories_to_run:
        logger.info(
            f"🔍 Orchestrating news intelligence: '{cat}' (limit={limit_per_category})..."
        )
        prompt = build_orchestrator_prompt(category=cat, limit=limit_per_category)

        try:
            response_text = await llm.generate_chat(
                system_instruction=prompt,
                contents=[
                    {
                        "role": "user",
                        "content": f"Discover {limit_per_category} trending {cat} as JSON.",
                    }
                ],
                temperature=0.3,
                response_format_json=True,
            )

            articles = parse_trending_articles_json(response_text)
            logger.info(f"✨ Parsed {len(articles)} articles for category '{cat}'")

            for art in articles:
                all_articles.append(art)
                if not dry_run and db is not None:
                    await upsert_trending_article(db, article_in=art)
                    logger.info(f"💾 Persisted: [{art.category.upper()}] {art.title[:45]}...")
                elif dry_run:
                    logger.info(f"🧪 [Dry-Run] [{art.category.upper()}] {art.title}")

        except Exception as exc:
            logger.error(f"❌ Failed to orchestrate category '{cat}': {exc}", exc_info=True)

    logger.info(f"🎉 Orchestration completed. Total curated articles: {len(all_articles)}")
    return all_articles


async def main() -> None:
    """CLI execution entrypoint."""
    args = parse_cli_args()
    logger.info(
        f"🚀 Starting Hermes News Orchestrator: category='{args.category}', limit={args.limit}"
    )

    if args.dry_run:
        articles = await run_news_orchestrator(
            category=args.category,
            limit_per_category=args.limit,
            dry_run=True,
        )
        print(f"\nCurated {len(articles)} trending articles (Dry-Run):")
        for i, a in enumerate(articles, 1):
            print(f"{i}. [{a.category.upper()}] {a.title} ({a.source_url})")
            print(f"   Summary: {a.summary[:100]}...\n")
    else:
        async with async_session_factory() as session:
            articles = await run_news_orchestrator(
                category=args.category,
                limit_per_category=args.limit,
                db=session,
                dry_run=False,
            )
            print(
                f"\nSuccessfully curated and saved {len(articles)} trending articles to database."
            )


if __name__ == "__main__":
    asyncio.run(main())
