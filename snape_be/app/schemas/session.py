from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.message import MessageResponse


class SessionBase(BaseModel):
    title: str = Field(default="Casual English Chat", max_length=255, description="Session title")


class SessionCreate(SessionBase):
    user_id: UUID | None = Field(default=None, description="Owner user ID")


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
