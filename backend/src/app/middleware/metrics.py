"""Prometheus metrics middleware for FastAPI."""

import time
from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from src.app.core.metrics import (
    ACTIVE_REQUESTS,
    HTTP_REQUEST_DURATION_SECONDS,
    HTTP_REQUESTS_TOTAL,
)


class PrometheusMiddleware(BaseHTTPMiddleware):

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        if request.url.path == "/metrics":
            return await call_next(request)
        
        ACTIVE_REQUESTS.inc()
        start_time = time.perf_counter()
        
        try:
            response = await call_next(request)
            
            duration = time.perf_counter() - start_time
            endpoint = self._get_endpoint_label(request)
            
            HTTP_REQUESTS_TOTAL.labels(
                method=request.method,
                endpoint=endpoint,
                status_code=response.status_code,
            ).inc()
            
            HTTP_REQUEST_DURATION_SECONDS.labels(
                method=request.method,
                endpoint=endpoint,
            ).observe(duration)
            
            return response
            
        except Exception as e:
            duration = time.perf_counter() - start_time
            endpoint = self._get_endpoint_label(request)
            
            HTTP_REQUESTS_TOTAL.labels(
                method=request.method,
                endpoint=endpoint,
                status_code=500,
            ).inc()
            
            HTTP_REQUEST_DURATION_SECONDS.labels(
                method=request.method,
                endpoint=endpoint,
            ).observe(duration)
            
            raise
            
        finally:
            ACTIVE_REQUESTS.dec()
    
    def _get_endpoint_label(self, request: Request) -> str:
        path = request.url.path
        
        if path.startswith("/api/v1/chat"):
            return "/api/v1/chat"
        elif path.startswith("/api/v1/admin"):
            return "/api/v1/admin"
        elif path == "/health":
            return "/health"
        elif path == "/metrics":
            return "/metrics"
        
        return path
