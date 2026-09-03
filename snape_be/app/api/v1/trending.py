from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.trending import (
    VALID_TRENDING_CATEGORIES,
    TrendingArticleResponse,
    TrendingSyncRequest,
    TrendingSyncResponse,
)
from app.services import trending_service

router = APIRouter(prefix="/trending", tags=["Trending"])


@router.get("", response_model=list[TrendingArticleResponse])
async def list_trending(
    category: str | None = Query(
        default=None,
        description="Filter by category ('politics', 'general', 'music', 'creator_trends')",
    ),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
) -> list[TrendingArticleResponse]:
    """Retrieve trending articles ordered by publication date, with optional category filtering."""
    if category is not None and category.strip().lower() != "all":
        cat_clean = category.strip().lower()
        if cat_clean not in VALID_TRENDING_CATEGORIES:
            valid_cats = list(VALID_TRENDING_CATEGORIES)
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid category '{category}'. Valid categories: {valid_cats} or 'all'",
            )
    articles = await trending_service.list_trending_articles(
        db=db, category=category, limit=limit, offset=offset
    )
    return [TrendingArticleResponse.model_validate(a) for a in articles]


@router.get("/{article_id}", response_model=TrendingArticleResponse)
async def get_trending_article(
    article_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> TrendingArticleResponse:
    """Retrieve details for a single trending article."""
    article = await trending_service.get_trending_article_by_id(db=db, article_id=article_id)
    if not article:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trending article not found",
        )
    return TrendingArticleResponse.model_validate(article)


@router.post("/sync", response_model=TrendingSyncResponse, status_code=status.HTTP_200_OK)
async def trigger_trending_sync(
    sync_req: TrendingSyncRequest | None = None,
    db: AsyncSession = Depends(get_db),
) -> TrendingSyncResponse:
    """Trigger synchronization and curation of trending topics across categories."""
    req = sync_req or TrendingSyncRequest()
    result = await trending_service.sync_trending_topics(
        db=db,
        category=req.category,
        limit_per_category=req.limit_per_category,
    )
    return result
