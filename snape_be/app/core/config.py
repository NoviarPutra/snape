from pathlib import Path
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

# Path to snape_be directory
BASE_DIR = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Application
    APP_NAME: str = "Snape AI Companion"
    APP_VERSION: str = "0.1.0"
    APP_ENV: Literal["development", "testing", "production"] = "development"
    DEBUG: bool = False
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://postgres:postgres@localhost:5432/postgres",
        description="Async SQLAlchemy database connection URL",
    )
    SUPABASE_DB_HOST: str | None = None
    SUPABASE_DB_PORT: int = 5432
    SUPABASE_DB_USER: str = "postgres"
    SUPABASE_DB_PASSWORD: str | None = None
    SUPABASE_DB_NAME: str = "postgres"

    # Connection pool configuration
    DB_POOL_SIZE: int = 5
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 300

    # LLM & OmniRoute Gateway
    OMNIROUTE_BASE_URL: str = "http://localhost:20128/v1"
    OMNIROUTE_API_KEY: str = Field(default="", description="OmniRoute API key")
    OMNIROUTE_MODEL: str = "antigravity/gemini-3.7-flash-high"

    # Embedding Dimension (768-dim for pgvector)
    EMBEDDING_DIMENSION: int = 768

    # TTS Settings
    ENABLE_TTS: bool = True
    TTS_PROVIDER: str = "edge_tts"
    EDGE_TTS_VOICE: str = "en-US-ChristopherNeural"
    POCKET_TTS_VOICE: str = "af_sky"
    POCKET_TTS_DEVICE: str = "cpu"

    @property
    def async_database_url(self) -> str:
        """Returns a valid asyncpg connection URL."""
        url = self.DATABASE_URL
        # If DATABASE_URL is not set or default, but SUPABASE credentials are provided
        if (
            self.SUPABASE_DB_HOST
            and self.SUPABASE_DB_PASSWORD
            and (url == "postgresql+asyncpg://postgres:postgres@localhost:5432/postgres" or not url)
        ):
            url = (
                f"postgresql+asyncpg://{self.SUPABASE_DB_USER}:{self.SUPABASE_DB_PASSWORD}"
                f"@{self.SUPABASE_DB_HOST}:{self.SUPABASE_DB_PORT}/{self.SUPABASE_DB_NAME}?ssl=require"
            )

        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)

        # Ensure asyncpg ssl parameter format
        if "sslmode=require" in url:
            url = url.replace("sslmode=require", "ssl=require")

        return url


settings = Settings()
