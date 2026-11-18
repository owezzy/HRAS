"""Access control for the operational endpoints (admin and conversations)."""

import hmac
from typing import Annotated

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader

from src.app.core.config import Settings, get_settings

admin_key_header = APIKeyHeader(
    name="X-Admin-Key",
    auto_error=False,
    description="Admin API key. The server reads it from ADMIN_API_KEY.",
)


def require_admin(
    key: Annotated[str | None, Security(admin_key_header)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> None:
    """Allow the request only with the configured admin key.

    Fails closed: with no ADMIN_API_KEY on the server, every request is refused.
    The comparison runs in constant time so the key can't be guessed byte by byte.
    """
    expected = settings.admin_api_key
    if not expected or not key or not hmac.compare_digest(key.encode(), expected.encode()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin key required",
            headers={"WWW-Authenticate": "ApiKey"},
        )
