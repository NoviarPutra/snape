from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class MemoryBase(BaseModel):
    category: str = Field(
        default="fact", max_length=64, description="Category: fact, preference, goal, experience"
    )
    content: str = Field(..., min_length=1, description="Memory text content")


class MemoryCreate(MemoryBase):
    user_id: UUID
    embedding: list[float] = Field(
        ..., min_length=768, max_length=768, description="768-dim embedding vector"
    )


class MemoryResponse(MemoryBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    created_at: datetime


class MemoryQueryResult(MemoryResponse):
    similarity: float = Field(..., description="Cosine similarity score")
