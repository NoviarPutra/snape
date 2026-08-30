from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class UserBase(BaseModel):
    username: str = Field(..., max_length=64, description="Unique username of the learner")
    full_name: str | None = Field(default=None, max_length=128, description="Learner display name")
    native_language: str = Field(default="Indonesian", max_length=64, description="Native language")
    english_level: str = Field(
        default="Intermediate", max_length=32, description="Target English proficiency level"
    )


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=128)
    native_language: str | None = Field(default=None, max_length=64)
    english_level: str | None = Field(default=None, max_length=32)


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
