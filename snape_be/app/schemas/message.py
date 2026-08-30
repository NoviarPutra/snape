from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class MessageBase(BaseModel):
    role: str = Field(..., description="Message author role: user, assistant, system")
    content: str = Field(..., min_length=1, description="Text content of the message")
    audio_path: str | None = Field(default=None, description="Path to generated TTS audio")
    meta_info: dict[str, Any] | None = Field(
        default=None, description="Metadata such as latency or corrections"
    )


class MessageCreate(MessageBase):
    pass


class MessageResponse(MessageBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    session_id: UUID
    created_at: datetime
