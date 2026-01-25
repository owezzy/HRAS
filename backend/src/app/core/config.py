"""Application configuration using pydantic-settings."""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    Security Notes:
    - All sensitive values should be provided via environment variables
    - Never commit .env files with production secrets
    - Use AWS Secrets Manager or similar for production deployments
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ==========================================================================
    # Application Settings
    # ==========================================================================
    app_name: str = "HRAS - Human Rights Advisory System"
    app_version: str = "0.2.0"
    debug: bool = False
    app_env: str = "development"  # development, staging, production

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # ==========================================================================
    # Database
    # ==========================================================================
    database_url: str = "sqlite+aiosqlite:///./hras.db"

    # ==========================================================================
    # CORS Configuration
    # ==========================================================================
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "https://feature-backend-refactor-testing.d3q35zh7ig6w8u.amplifyapp.com",
        "https://hras.owezzy.tech",
    ]
    cors_allow_credentials: bool = True
    # Restrict methods and headers in production
    cors_allow_methods: list[str] = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    cors_allow_headers: list[str] = [
        "Accept",
        "Accept-Language",
        "Content-Type",
        "Authorization",
        "X-Request-ID",
        "X-Correlation-ID",
    ]

    # ==========================================================================
    # Security Settings
    # ==========================================================================
    # Trusted hosts for Host header validation (prevents host header injection)
    trusted_hosts: list[str] = ["localhost", "127.0.0.1"]

    # API documentation access (disable in production)
    docs_enabled: bool = True

    # Rate limiting (requests per minute per IP)
    rate_limit_requests: int = 60
    rate_limit_window_seconds: int = 60

    # Health check token for Route53 (optional additional security)
    health_check_token: str | None = None

    # ==========================================================================
    # Ollama / LLM Configuration
    # ==========================================================================
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "nemotron-3-nano:30b-cloud"
    ollama_embedding_model: str = "nomic-embed-text"
    ollama_timeout: int = 180  # seconds

    # ==========================================================================
    # Vector Store
    # ==========================================================================
    chroma_persist_directory: str = "./chroma_db"

    # ==========================================================================
    # UHRI API
    # ==========================================================================
    uhri_api_url: str = "https://uhri.ohchr.org/api"
    uhri_api_timeout: int = 30  # seconds

    # LangSmith Configuration - Tracing and Evaluation
    # ==========================================================================
    langsmith_api_key: str | None = None
    langsmith_project: str = "hras-production"
    langsmith_endpoint: str = "https://api.smith.langchain.com"

    # ==========================================================================

    # ==========================================================================
    # Feature Flags - gradual rollout of new features
    # ==========================================================================
    use_postgres: bool = False
    use_async_tools: bool = False
    use_langsmith_tracing: bool = False

    # ==========================================================================
    # Validators
    # ==========================================================================
    @field_validator("app_env")
    @classmethod
    def validate_app_env(cls, v: str) -> str:
        """Validate app_env is a known environment."""
        allowed = {"development", "staging", "production"}
        if v.lower() not in allowed:
            raise ValueError(f"app_env must be one of: {allowed}")
        return v.lower()

    @property
    def is_production(self) -> bool:
        """Check if running in production environment."""
        return self.app_env == "production"

    @property
    def is_development(self) -> bool:
        """Check if running in development environment."""
        return self.app_env == "development"


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
