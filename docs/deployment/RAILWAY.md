# Railway Deployment

Both services run on Railway and build from this repository.

## Services

| Service | Root Directory | Dockerfile | Public URL |
|---------|----------------|------------|------------|
| `frontend` | `frontend` | `Dockerfile.multi-stage` | https://hras.owenadirah.com |
| `backend` | `backend` | `Dockerfile` | https://backend-production-f15e.up.railway.app |

The frontend uses `Dockerfile.multi-stage` because `next.config.ts` sets
`output: 'standalone'`. Running `next start` against a standalone build does not
serve the static chunks correctly, so the multi-stage image is required.

## Deploying

Pushing to `main` deploys both services automatically. Railway builds each
service from its root directory; a failed build leaves the previous deployment
running.

To deploy a different branch, change the service's source branch in
**Settings → Source**.

## Required Variables

### backend

| Variable | Purpose |
|----------|---------|
| `LLM_API_KEY` | DeepSeek API key |
| `LLM_PROVIDER` | `deepseek` (see `LLM_PROVIDER_PRESETS` in `core/config.py`) |
| `LLM_MODEL` | e.g. `deepseek-flash` |
| `EMBEDDING_BASE_URL` | OpenAI-compatible host serving the embedding model |
| `EMBEDDING_API_KEY` | Key for that host |
| `EMBEDDING_MODEL` | e.g. `@cf/baai/bge-small-en-v1.5` |
| `CHROMA_PERSIST_DIRECTORY` | Must be inside the mounted volume |
| `CORS_ORIGINS` | JSON array including the frontend origin |
| `TRUSTED_HOSTS` | JSON array of accepted `Host` headers |

### frontend

| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_API_URL` | Backend URL — read at build time |
| `NEXT_PUBLIC_BASE_URL` | Public site URL |
| `AUTH_URL` | NextAuth URL |
| `AUTH_SECRET` | NextAuth session secret |

`NEXT_PUBLIC_*` values are inlined during `next build`, so changing them requires
a rebuild, not just a restart.

## Storage

ChromaDB persists to a volume mounted at `/app/chroma_db`. The container runs as
`appuser` (uid 1000) while Railway mounts volumes as root, so
`backend/docker-entrypoint.sh` starts as root, takes ownership of the directory,
then drops to `appuser` before launching the app. Without it ChromaDB fails with
`Could not connect to tenant default_tenant`.

## Health

```
GET /health           liveness, no dependency checks
GET /health/detailed  reports the active chat, embedding and tracing providers
```

The backend does **not** define a platform healthcheck path. Railway's health
probe sends an internal CGNAT address as the `Host` header, which
`TrustedHostMiddleware` rejects with `400 Invalid host header`.
