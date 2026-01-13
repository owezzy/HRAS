"""Async utilities for running blocking operations in thread pools."""

import asyncio
from collections.abc import Awaitable, Callable, Coroutine
from concurrent.futures import ThreadPoolExecutor
from functools import partial, wraps
from typing import Any, TypeVar

from src.app.core.config import get_settings

T = TypeVar("T")

_executor: ThreadPoolExecutor | None = None


def get_executor() -> ThreadPoolExecutor:
    """Get or create the shared thread pool executor."""
    global _executor
    if _executor is None:
        _executor = ThreadPoolExecutor(max_workers=4, thread_name_prefix="hras-async-")
    return _executor


def shutdown_executor() -> None:
    """Shutdown the thread pool executor gracefully."""
    global _executor
    if _executor is not None:
        _executor.shutdown(wait=True)
        _executor = None


async def run_in_thread[T](func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
    """Run a synchronous function in a thread pool.

    Useful for blocking I/O operations (like ChromaDB calls) without blocking
    the async event loop.
    """
    loop = asyncio.get_running_loop()

    if kwargs:
        func = partial(func, **kwargs)
        return await loop.run_in_executor(get_executor(), func, *args)

    return await loop.run_in_executor(get_executor(), func, *args)


def async_wrap[T](func: Callable[..., T]) -> Callable[..., Coroutine[Any, Any, T]]:
    """Decorator to wrap a synchronous function for async execution in thread pool."""

    @wraps(func)
    async def wrapper(*args: Any, **kwargs: Any) -> T:
        return await run_in_thread(func, *args, **kwargs)

    return wrapper


async def gather_with_limit[T](
    *coroutines: Awaitable[T],
    limit: int = 10,
    return_exceptions: bool = False,
) -> list[T | BaseException]:
    """Run multiple coroutines with a concurrency limit."""
    semaphore = asyncio.Semaphore(limit)

    async def limited_coro(coro: Awaitable[T]) -> T:
        async with semaphore:
            return await coro

    limited = [limited_coro(coro) for coro in coroutines]
    return await asyncio.gather(*limited, return_exceptions=return_exceptions)


def is_async_enabled() -> bool:
    """Check if async tools are enabled via feature flag."""
    settings = get_settings()
    return settings.use_async_tools
