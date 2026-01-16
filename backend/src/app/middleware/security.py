"""Security middleware for HRAS backend.

Implements OWASP-recommended security headers and request validation.
"""

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from src.app.core.config import get_settings


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Add security headers to all responses.

    Implements headers recommended by:
    - OWASP Secure Headers Project
    - Mozilla Web Security Guidelines
    - NIST Cybersecurity Framework
    """

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        settings = get_settings()

        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

        if settings.is_production:
            response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains; preload"

        response.headers["Permissions-Policy"] = (
            "accelerometer=(), "
            "camera=(), "
            "geolocation=(), "
            "gyroscope=(), "
            "magnetometer=(), "
            "microphone=(), "
            "payment=(), "
            "usb=()"
        )

        if request.url.path.startswith("/api/"):
            response.headers["Content-Security-Policy"] = (
                "default-src 'none'; frame-ancestors 'none'; form-action 'none'"
            )
            response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
            response.headers["Pragma"] = "no-cache"

        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Resource-Policy"] = "same-origin"

        return response
