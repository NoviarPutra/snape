from pydantic import BaseModel, ConfigDict, Field


class SpacePublicResponse(BaseModel):
    model_config = ConfigDict(from_attributes=False)

    slug: str = Field(..., description="Unique space slug identifier")
    display_name: str = Field(..., description="User-friendly display name")
    cefr_level: str | None = Field(
        default=None, description="CEFR level for English learning spaces"
    )
    tts_enabled: bool = Field(..., description="Whether Text-to-Speech is enabled")
    voice_call_enabled: bool = Field(..., description="Whether Voice Call mode is enabled")
