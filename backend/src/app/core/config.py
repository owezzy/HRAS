"""Application configuration using pydantic-settings."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_name: str = "HRAS - Human Rights Advisory System"
    app_version: str = "0.2.0"
    debug: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Database
    database_url: str = "sqlite+aiosqlite:///./hras.db"

    # CORS
    cors_origins: list[str] = ["http://localhost:3000", "http://127.0.0.1:3000"]

    # Ollama
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "nemotron-3-nano:30b-cloud"
    ollama_embedding_model: str = "nomic-embed-text"

    # Vector Store
    chroma_persist_directory: str = "./chroma_db"

    # UHRI API
    uhri_api_url: str = "https://uhri.ohchr.org/api"

    # Feature Flags - gradual rollout of new features
    use_postgres: bool = False
    use_async_tools: bool = False


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
