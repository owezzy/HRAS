"""The admin and conversation endpoints need the admin key; nothing else does."""

import pytest
from httpx import ASGITransport, AsyncClient

from src.app.core.config import get_settings
from src.app.main import create_app

PROTECTED = [
    ("GET", "/api/v1/admin/stats"),
    ("POST", "/api/v1/admin/ingest"),
    ("GET", "/api/v1/conversations"),
    ("GET", "/api/v1/conversations/some-id"),
    ("DELETE", "/api/v1/conversations/some-id"),
]


async def _client(app, headers=None) -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test", headers=headers or {})


@pytest.mark.parametrize(("method", "path"), PROTECTED)
async def test_missing_key_is_refused(method, path):
    async with await _client(create_app()) as client:
        response = await client.request(method, path)

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "ApiKey"


@pytest.mark.parametrize(("method", "path"), PROTECTED)
async def test_wrong_key_is_refused(method, path):
    async with await _client(create_app(), {"X-Admin-Key": "not-the-key"}) as client:
        response = await client.request(method, path)

    assert response.status_code == 401


async def test_right_key_passes_the_check():
    # Conversations answer 503 while Postgres is off: past the key check, before any data.
    async with await _client(create_app(), {"X-Admin-Key": "test-admin-key"}) as client:
        response = await client.get("/api/v1/conversations")

    assert response.status_code != 401


async def test_server_without_a_key_refuses_everyone():
    app = create_app()
    app.dependency_overrides[get_settings] = lambda: get_settings().model_copy(update={"admin_api_key": ""})
    async with await _client(app, {"X-Admin-Key": ""}) as client:
        response = await client.get("/api/v1/admin/stats")

    assert response.status_code == 401


async def test_public_endpoints_need_no_key():
    async with await _client(create_app()) as client:
        response = await client.get("/health")

    assert response.status_code == 200


def test_openapi_declares_the_admin_key():
    schema = create_app().openapi()

    assert "APIKeyHeader" in schema["components"]["securitySchemes"]
    assert schema["paths"]["/api/v1/admin/ingest"]["post"]["security"] == [{"APIKeyHeader": []}]
    assert "security" not in schema["paths"]["/api/v1/chat"]["post"]
