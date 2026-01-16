# Docker Build Configuration

This directory contains Dockerfiles for building HRAS container images following the Ardan Labs project structure.

## Directory Structure

```
zarf/docker/
├── compose/                  # Docker Compose files
│   ├── docker-compose.yml        # Base development compose
│   ├── docker-compose.dev.yml    # Development with hot reload
│   ├── docker-compose.prod.yml   # Production deployment
│   └── docker-compose.minimal.yml # Budget t3.small deployment
├── monitoring/              # Monitoring stack configs
├── dockerfile.backend       # FastAPI backend API server
├── hras.service            # Systemd service file
├── install-service.sh      # EC2 installer script
└── README.md               # This file
```

## Building Images

All Dockerfiles are designed to be built from the **repository root** using the `-f` flag to specify the Dockerfile path. This allows each Dockerfile to access all necessary source files.

### Backend API

```bash
# Build from repo root
docker build -f zarf/docker/dockerfile.backend -t hras-backend .

# Build with specific tag
docker build -f zarf/docker/dockerfile.backend -t hras-backend:v1.0.0 .

# Build for production registry
docker build -f zarf/docker/dockerfile.backend -t your-registry/hras-backend:latest .
```

### Build Arguments

The backend Dockerfile uses multi-stage builds with the following features:

- **Builder stage**: Uses `uv` for fast Python dependency management
- **Runtime stage**: Slim Python 3.12 image for minimal attack surface
- **Non-root user**: Runs as `appuser` (UID 1000) for security
- **Health check**: Built-in health check endpoint at `/health`

## Using with Docker Compose

Reference the Dockerfiles in docker-compose files:

```yaml
services:
  backend:
    build:
      context: .                                    # Repo root
      dockerfile: zarf/docker/dockerfile.backend   # Dockerfile path
    ports:
      - "8000:8000"
```

## Using with Kubernetes

For Kubernetes deployments, pre-built images should be pushed to a container registry:

```bash
# Build and push to registry
docker build -f zarf/docker/dockerfile.backend -t your-registry/hras-backend:latest .
docker push your-registry/hras-backend:latest
```

Then reference in Kubernetes manifests:

```yaml
containers:
  - name: backend
    image: your-registry/hras-backend:latest
```

## Development vs Production

### Development
- Use `zarf/docker/compose/docker-compose.dev.yml` for local development with hot reloading
- Mounts source code as volumes for faster iteration

### Production
- Use `zarf/docker/compose/docker-compose.prod.yml` for production
- Use `zarf/docker/compose/docker-compose.minimal.yml` for budget deployments (t3.small)
- Pre-built images from registry
- Images are optimized for size and security
- Non-root user execution
- Health checks enabled

## Image Details

### Backend Image

| Property | Value |
|----------|-------|
| Base Image | `python:3.12-slim-bookworm` |
| Exposed Port | 8000 |
| User | `appuser` (UID 1000) |
| Health Check | `GET /health` every 30s |
| Python Path | `/app/.venv/bin` |

## Troubleshooting

### Build Context Issues

If you get "file not found" errors, ensure you're running from the repository root:

```bash
# Correct - from repo root
cd /path/to/HRAS
docker build -f zarf/docker/dockerfile.backend -t hras-backend .

# Incorrect - from zarf/docker
cd /path/to/HRAS/zarf/docker
docker build -f dockerfile.backend -t hras-backend .  # Will fail!
```

### Cache Issues

To build without cache:

```bash
docker build --no-cache -f zarf/docker/dockerfile.backend -t hras-backend .
```

### Multi-platform Builds

For building images that work on multiple architectures (e.g., amd64 and arm64):

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f zarf/docker/dockerfile.backend \
  -t your-registry/hras-backend:latest \
  --push .
```
