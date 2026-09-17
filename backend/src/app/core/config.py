"""Application configuration using pydantic-settings."""

from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Chat and embeddings are configured INDEPENDENTLY: DeepSeek, OpenRouter and
# Ollama Cloud all serve chat but expose NO embeddings endpoint.
LLM_PROVIDER_PRESETS: dict[str, dict[str, str]] = {
    "deepseek": {"base_url": "https://api.deepseek.com", "model": "deepseek-flash"},
    "openai": {"base_url": "https://api.openai.com/v1", "model": "gpt-4o-mini"},
    "openrouter": {"base_url": "https://openrouter.ai/api/v1", "model": ""},
    "ollama": {"base_url": "http://localhost:11434/v1", "model": "llama3.2"},
    "custom": {"base_url": "", "model": ""},
}


def llm_provider_preset(provider: str) -> dict[str, str]:
    """Resolve a chat provider preset, rejecting unknown provider names."""
    preset = LLM_PROVIDER_PRESETS.get(provider)
    if preset is None:
        known = ", ".join(sorted(LLM_PROVIDER_PRESETS))
        raise ValueError(f"Unknown llm_provider {provider!r}. Expected one of: {known}")
    return preset


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
    # Chat LLM Configuration (OpenAI-compatible)
    # --------------------------------------------------------------------------
    # Configured independently from embeddings. Set llm_provider to a preset
    # (deepseek | openai | openrouter | ollama | custom) or override base_url
    # and model explicitly. Explicit values always win over the preset.
    # ==========================================================================
    llm_provider: str = "deepseek"
    llm_base_url: str | None = None
    llm_api_key: str = ""
    llm_model: str | None = None
    llm_temperature: float = 0.1
    llm_timeout: int = 180  # seconds
    llm_max_retries: int = 2

    # ==========================================================================
    # Embeddings Configuration (OpenAI-compatible, independent of chat)
    # --------------------------------------------------------------------------
    # Changing embedding_model invalidates the persisted ChromaDB index and
    # forces a full re-ingestion of the UHRI corpus: it must stay
    # nomic-embed-text-v1.5 to match the vectors already stored.
    # ==========================================================================
    embedding_base_url: str = "http://localhost:11434/v1"
    embedding_api_key: str = ""
    embedding_model: str = "nomic-embed-text-v1.5"
    embedding_dimensions: int | None = None
    embedding_timeout: int = 180  # seconds
    embedding_max_retries: int = 2

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
    # LangSmith Evaluation Settings - Phase 2
    # ==========================================================================
    enable_production_evaluations: bool = False
    weekly_evaluation_enabled: bool = False

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

    @property
    def resolved_llm_base_url(self) -> str:
        base_url = self.llm_base_url or llm_provider_preset(self.llm_provider)["base_url"]
        if not base_url:
            raise ValueError(f"llm_base_url must be set when llm_provider={self.llm_provider!r}")
        return base_url

    @property
    def resolved_llm_model(self) -> str:
        model = self.llm_model or llm_provider_preset(self.llm_provider)["model"]
        if not model:
            raise ValueError(f"llm_model must be set when llm_provider={self.llm_provider!r}")
        return model

    @property
    def resolved_llm_api_key(self) -> str:
        if self.llm_api_key:
            return self.llm_api_key
        if self.llm_provider == "ollama":
            # A local Ollama server requires a key value but ignores it.
            return "ollama"
        raise ValueError(f"llm_api_key must be set when llm_provider={self.llm_provider!r}")

    @property
    def resolved_embedding_api_key(self) -> str:
        if self.embedding_api_key:
            return self.embedding_api_key
        if "localhost" in self.embedding_base_url or "127.0.0.1" in self.embedding_base_url:
            return "ollama"
        raise ValueError("embedding_api_key must be set for hosted embedding providers")


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
