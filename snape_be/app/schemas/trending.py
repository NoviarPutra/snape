from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator

VALID_TRENDING_CATEGORIES: tuple[str, ...] = ("politics", "general", "music", "creator_trends")


class TrendingArticleBase(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    category: str = Field(
        ...,
        description="Article category ('politics', 'general', 'music', 'creator_trends')",
    )
    title: str = Field(..., min_length=1, max_length=255, description="Article title")
    summary: str = Field(
        ...,
        min_length=1,
        description="Bulleted digest and 'Why It's Trending' rationale",
    )
    source_url: str = Field(..., min_length=1, max_length=512, description="Source article URL")
    published_at: datetime | None = Field(
        default=None,
        description="Original publication timestamp (UTC)",
    )
    tags: list[str] = Field(
        default_factory=list,
        description="Keywords and thematic tags",
    )
    metadata: dict[str, Any] = Field(
        default_factory=dict,
        validation_alias=AliasChoices("metadata_", "metadata"),
        serialization_alias="metadata",
        description="Viral metrics and discussion hooks",
    )

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        v_clean = v.strip().lower()
        if v_clean not in VALID_TRENDING_CATEGORIES:
            raise ValueError(
                f"Invalid category '{v}'. Allowed categories are: {list(VALID_TRENDING_CATEGORIES)}"
            )
        return v_clean


class TrendingArticleCreate(TrendingArticleBase):
    pass


class TrendingArticleUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    summary: str | None = None
    source_url: str | None = Field(default=None, max_length=512)
    published_at: datetime | None = None
    tags: list[str] | None = None
    metadata: dict[str, Any] | None = None


class TrendingArticleResponse(TrendingArticleBase):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: UUID
    published_at: datetime
    created_at: datetime


class TrendingSyncRequest(BaseModel):
    category: str | None = Field(
        default=None,
        description="Category to sync ('politics', 'general', 'music', 'creator_trends', or 'all')",
    )
    limit_per_category: int = Field(
        default=5,
        ge=1,
        le=20,
        description="Maximum articles to scrape and summarize per category",
    )

    @field_validator("category")
    @classmethod
    def validate_sync_category(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v_clean = v.strip().lower()
        if v_clean == "all":
            return "all"
        if v_clean not in VALID_TRENDING_CATEGORIES:
            valid_cats = list(VALID_TRENDING_CATEGORIES)
            raise ValueError(
                f"Invalid category '{v}'. Allowed categories are: {valid_cats} or 'all'"
            )
        return v_clean


class TrendingSyncResponse(BaseModel):
    status: str = Field(..., description="Sync execution status ('success', 'partial', 'failed')")
    synced_count: int = Field(..., description="Total new/updated articles persisted")
    categories: list[str] = Field(..., description="Categories targeted in this sync run")
    message: str = Field(..., description="Human-readable summary message")
