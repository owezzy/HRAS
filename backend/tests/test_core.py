import os
from unittest.mock import patch

import pytest

from src.app.core.async_utils import (
    async_wrap,
    gather_with_limit,
    get_executor,
    is_async_enabled,
    run_in_thread,
    shutdown_executor,
)
from src.app.core.config import Settings, get_settings


class TestSettings:
    def test_default_settings(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings(_env_file=None)

        assert settings.app_name == "HRAS - Human Rights Advisory System"
        assert settings.app_version == "0.2.0"
        assert settings.debug is False
        assert settings.host == "0.0.0.0"
        assert settings.port == 8000

    def test_feature_flags_default_to_false(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings(_env_file=None)

        assert settings.use_postgres is False
        assert settings.use_async_tools is False

    def test_provider_defaults(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings(_env_file=None)

        assert settings.llm_provider == "deepseek"
        assert settings.embedding_model == "nomic-embed-text-v1.5"

    def test_deepseek_preset_resolution(self):
        settings = Settings(_env_file=None, llm_provider="deepseek")

        assert settings.resolved_llm_base_url == "https://api.deepseek.com"
        assert settings.resolved_llm_model == "deepseek-flash"

    def test_explicit_values_override_preset(self):
        settings = Settings(
            _env_file=None,
            llm_provider="deepseek",
            llm_base_url="https://example.test/v1",
            llm_model="some-other-model",
        )

        assert settings.resolved_llm_base_url == "https://example.test/v1"
        assert settings.resolved_llm_model == "some-other-model"

    def test_openrouter_requires_explicit_model(self):
        settings = Settings(_env_file=None, llm_provider="openrouter")

        with pytest.raises(ValueError, match="llm_model must be set"):
            _ = settings.resolved_llm_model

    def test_unknown_provider_is_rejected(self):
        settings = Settings(_env_file=None, llm_provider="not-a-provider")

        with pytest.raises(ValueError, match="Unknown llm_provider"):
            _ = settings.resolved_llm_base_url

    def test_ollama_preset_supplies_placeholder_api_key(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings(_env_file=None, llm_provider="ollama")

        assert settings.resolved_llm_api_key == "ollama"
        assert settings.resolved_llm_base_url == "http://localhost:11434/v1"

    def test_hosted_provider_requires_api_key(self):
        settings = Settings(_env_file=None, llm_provider="deepseek", llm_api_key="")

        with pytest.raises(ValueError, match="llm_api_key must be set"):
            _ = settings.resolved_llm_api_key

    def test_embeddings_default_to_local_ollama(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings(_env_file=None)

        assert settings.embedding_base_url == "http://localhost:11434/v1"
        assert settings.embedding_model == "nomic-embed-text-v1.5"
        assert settings.resolved_embedding_api_key == "ollama"

    def test_hosted_embeddings_require_api_key(self):
        settings = Settings(
            _env_file=None,
            embedding_base_url="https://api.example.test/v1",
            embedding_api_key="",
        )

        with pytest.raises(ValueError, match="embedding_api_key must be set"):
            _ = settings.resolved_embedding_api_key

    def test_cors_origins_default(self):
        settings = Settings()

        assert "http://localhost:3000" in settings.cors_origins
        assert "http://127.0.0.1:3000" in settings.cors_origins

    def test_get_settings_returns_settings(self):
        get_settings.cache_clear()
        settings = get_settings()

        assert isinstance(settings, Settings)


class TestAsyncUtils:
    async def test_run_in_thread_executes_sync_function(self):
        def sync_add(a: int, b: int) -> int:
            return a + b

        result = await run_in_thread(sync_add, 2, 3)

        assert result == 5

    async def test_run_in_thread_with_kwargs(self):
        def sync_greet(name: str, prefix: str = "Hello") -> str:
            return f"{prefix}, {name}!"

        result = await run_in_thread(sync_greet, "World", prefix="Hi")

        assert result == "Hi, World!"

    async def test_async_wrap_decorator(self):
        @async_wrap
        def sync_multiply(x: int, y: int) -> int:
            return x * y

        result = await sync_multiply(4, 5)

        assert result == 20

    async def test_gather_with_limit(self):
        call_order = []

        async def track_call(n: int) -> int:
            call_order.append(n)
            return n * 2

        results = await gather_with_limit(
            track_call(1),
            track_call(2),
            track_call(3),
            limit=2,
        )

        assert sorted(results) == [2, 4, 6]
        assert len(call_order) == 3

    async def test_gather_with_limit_handles_exceptions(self):
        async def fail() -> None:
            raise ValueError("test error")

        async def succeed() -> int:
            return 42

        results = await gather_with_limit(
            succeed(),
            fail(),
            succeed(),
            limit=3,
            return_exceptions=True,
        )

        assert results[0] == 42
        assert isinstance(results[1], ValueError)
        assert results[2] == 42

    def test_get_executor_creates_executor(self):
        shutdown_executor()
        executor = get_executor()

        assert executor is not None
        assert executor._max_workers == 4

        shutdown_executor()

    def test_shutdown_executor(self):
        get_executor()
        shutdown_executor()

        import src.app.core.async_utils as module

        assert module._executor is None

    def test_is_async_enabled_returns_feature_flag(self):
        with patch("src.app.core.async_utils.get_settings") as mock_settings:
            mock_settings.return_value.use_async_tools = True
            assert is_async_enabled() is True

            mock_settings.return_value.use_async_tools = False
            assert is_async_enabled() is False
