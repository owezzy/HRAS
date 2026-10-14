# Cloudflare Deployment

Both services run on Cloudflare and deploy with Wrangler from this repository.

## Services

| Service | Directory | Runtime | Public URL |
|---------|-----------|---------|------------|
| `hras-frontend` | `frontend` | Worker via [OpenNext](https://opennext.js.org/cloudflare) | https://hras.owenadirah.com |
| `hras-backend` | `backend/cloudflare` | Worker + Container built from `backend/Dockerfile` | https://hras-api.owenadirah.com |

The backend Worker forwards every request to one named container instance
(`max_instances: 1`). The container sleeps after 30 minutes without requests and
starts again on the next request.

## Prerequisites

- Workers Paid plan (Containers need it)
- `owenadirah.com` zone on Cloudflare, with no existing DNS records for
  `hras` or `hras-api`. Wrangler creates the custom-domain records, and the
  deploy fails if a record already exists.
- Docker running locally, because Wrangler builds the backend image (`linux/amd64`)
- `npx wrangler login`

## Deploying

```bash
# Backend
cd backend/cloudflare
npm ci
npm run deploy

# Frontend (NEXT_PUBLIC_* values come from frontend/.env.production at build time)
cd frontend
npm ci
npm run deploy
```

To check the frontend Worker locally, run `npm run preview` in `frontend`.

## Secrets

Set each secret once with `npx wrangler secret put <NAME>`, from the
service directory:

| Service | Secret | Purpose |
|---------|--------|---------|
| backend | `LLM_API_KEY` | DeepSeek API key |
| backend | `EMBEDDING_API_KEY` | Workers AI API token |
| backend | `EMBEDDING_BASE_URL` | `https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1` |
| backend | `LANGSMITH_API_KEY` | Only when `USE_LANGSMITH_TRACING` is `true` |
| frontend | `AUTH_SECRET` | NextAuth session secret |

The other settings are `vars` in each `wrangler.jsonc`. The backend Worker
passes every var and secret to the container as an environment variable.

## Storage

Containers have no persistent disk. ChromaDB and the SQLite database are
lost when the container stops or redeploys.

- **Vector store:** `AUTO_INGEST_ON_EMPTY=true` makes the backend ingest the
  sample UHRI data in the background on each cold start. For the first few seconds
  after a start, chat replies that the store is empty. Data added with
  `POST /api/v1/admin/ingest` is lost on the next stop.
- **Conversations:** SQLite under `/app`, which is also ephemeral.

## Custom domains

Wrangler creates the DNS record for each custom domain. It refuses when the
hostname already has a DNS record (error `100117`), so delete any old record in
the Cloudflare dashboard (**DNS → Records**) and run `npm run deploy` again.

## Rollback

Each deploy creates a Worker version. To go back one version, run
`npx wrangler rollback` in the service directory. For the backend, this
rolls back the Worker only, not the container image; redeploy an earlier commit
to restore an earlier image.
