import os
from unittest.mock import patch

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

    def test_ollama_defaults(self):
        settings = Settings()

        assert settings.ollama_base_url == "http://localhost:11434"
        assert settings.ollama_model == "nemotron-3-nano:30b-cloud"
        assert settings.ollama_embedding_model == "nomic-embed-text"

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
