from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.space_config import SPACE_REGISTRY
from app.schemas.message import MessageResponse


class SessionBase(BaseModel):
    title: str = Field(..., max_length=255, description="Session title")
    space_slug: str = Field(
        default="english_b2", max_length=32, description="Discussion space slug"
    )


class SessionCreate(BaseModel):
    title: str | None = Field(
        default=None, max_length=255, description="Session title (defaults to space display name)"
    )
    space_slug: str = Field(
        default="english_b2", max_length=32, description="Target discussion space slug"
    )
    user_id: UUID | None = Field(default=None, description="Owner user ID")

    @field_validator("space_slug")
    @classmethod
    def validate_space_slug(cls, v: str) -> str:
        if v not in SPACE_REGISTRY:
            raise ValueError(
                f"Unknown space_slug: '{v}'. Valid slugs are: {list(SPACE_REGISTRY.keys())}"
            )
        return v


class SessionUpdate(BaseModel):
    title: str = Field(..., max_length=255, description="Updated session title")


class SessionResponse(SessionBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime


class SessionDetailResponse(SessionResponse):
    messages: list[MessageResponse] = Field(
        default_factory=list, description="Messages in chronological order"
    )
