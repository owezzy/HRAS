# Cloudflare Deployment

Both services run on Cloudflare and deploy from this repository with Wrangler.

## Services

| Service | Directory | Runs as | Public URL |
|---------|-----------|---------|------------|
| `hras-frontend` | `frontend` | Worker, built with [OpenNext](https://opennext.js.org/cloudflare) | https://hras.owenadirah.com |
| `hras-backend` | `backend/cloudflare` | Worker in front of a `basic` Container (1/4 vCPU, 1 GiB) built from `backend/Dockerfile` | https://hras-api.owenadirah.com |

Containers have no persistent disk, so the backend stores vectors in
Cloudflare Vectorize (`VECTOR_STORE_BACKEND=vectorize`) instead of ChromaDB.
Embeddings come from Workers AI (`@cf/baai/bge-small-en-v1.5`, 384 dimensions).
The container sleeps after 10 idle minutes; the first request after that waits
for a cold start.

## One-time setup

Create the Vectorize index and the metadata indexes the agent tools filter on:

```bash
cd backend/cloudflare
npm ci
npx wrangler vectorize create hras-uhri --dimensions=384 --metric=cosine
for p in country mechanism theme; do
  npx wrangler vectorize create-metadata-index hras-uhri --property-name=$p --type=string
done
```

Create an API token with **Vectorize: Edit** and **Workers AI: Read**, then set
the backend secrets and your account ID (`CLOUDFLARE_ACCOUNT_ID` in
`backend/cloudflare/wrangler.jsonc` `vars`):

```bash
npx wrangler secret put LLM_API_KEY            # DeepSeek key
npx wrangler secret put CLOUDFLARE_API_TOKEN   # Vectorize + Workers AI token
```

Set the frontend session secret:

```bash
cd frontend
npx wrangler secret put AUTH_SECRET
```

## Deploying

```bash
# Backend (needs Docker to build the container image)
cd backend/cloudflare && npx wrangler deploy

# Frontend
cd frontend && npm run deploy
```

Both `wrangler.jsonc` files claim their hostname as a Workers custom domain,
which replaces the old Railway DNS records for `hras.owenadirah.com`.

## Loading the corpus

The Vectorize index starts empty. Ingest the UHRI recommendations once after
the first backend deploy:

```bash
curl -X POST https://hras-api.owenadirah.com/api/v1/admin/ingest \
  -H 'Content-Type: application/json' \
  -d '{"clear_existing": false, "use_sample": true}'
curl https://hras-api.owenadirah.com/api/v1/admin/stats
```

Vector IDs are derived from the document text, so re-running the ingest
overwrites instead of duplicating.

## Health

```
GET /health           liveness, no dependency checks
GET /health/detailed  reports the active chat, embedding and tracing providers
```

`TRUSTED_HOSTS` must include `hras-api.owenadirah.com`; requests reach the
container with that `Host` header.
