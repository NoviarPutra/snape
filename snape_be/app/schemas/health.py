from datetime import UTC, datetime

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: str = Field(default="healthy", description="Service health status")
    version: str = Field(default="0.1.0", description="Application version")
    environment: str = Field(default="development", description="Runtime environment")
    database_connected: bool = Field(default=False, description="Database connection status")
    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(UTC), description="Server timestamp (UTC)"
    )
