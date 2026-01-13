# ⚙️ HRAS Configuration Reference

*Complete guide to configuring HRAS for your environment*

---

## 🎯 Configuration at a Glance

HRAS follows a **"configuration-as-code"** philosophy - everything is controlled through environment variables, making it easy to deploy across different environments without code changes.

### 📋 **Quick Reference Card**

| Component | Config File | Key Settings |
|-----------|-------------|--------------|
| **Backend** | `backend/.env` | Ollama URL, Models, Database |
| **Frontend** | `frontend/.env.local` | API URL, Feature Flags |
| **Kubernetes** | `k8s/dev/backend/dev-backend-configmap.yaml` | Environment-specific overrides |
| **Docker** | `docker-compose.yml` + `.env` | Container orchestration |

---

## 🔧 Backend Configuration (`backend/.env`)

### Essential Settings

```bash
# 🤖 AI/LLM Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# 💾 Data Storage
CHROMA_PERSIST_DIRECTORY=./chroma_db
DATABASE_URL=sqlite+aiosqlite:///./hras.db

# 🌐 Network & Security
CORS_ORIGINS=["http://localhost:3000"]
```

### Complete Variable Reference

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| **🤖 AI & LLM** |
| `OLLAMA_BASE_URL` | ✅ | `http://localhost:11434` | Ollama server endpoint | `http://your-ollama:11434` |
| `OLLAMA_MODEL` | ✅ | `nemotron-3-nano:30b-cloud` | Chat completion model | `llama2:7b-chat` |
| `OLLAMA_EMBEDDING_MODEL` | ✅ | `nomic-embed-text` | Text embedding model | `all-minilm:l6-v2` |
| **💾 Storage** |
| `CHROMA_PERSIST_DIRECTORY` | ✅ | `./chroma_db` | Vector database path | `/data/chromadb` |
| `DATABASE_URL` | ✅ | `sqlite+aiosqlite:///./hras.db` | Main database connection | `postgresql+asyncpg://user:pass@host/db` |
| **🌐 Network** |
| `CORS_ORIGINS` | ❌ | `["http://localhost:3000"]` | Allowed frontend origins | `["https://hras.yourorg.com"]` |
| `HOST` | ❌ | `0.0.0.0` | Server bind address | `127.0.0.1` |
| `PORT` | ❌ | `8000` | Server port | `8080` |
| **📊 Logging & Debug** |
| `LOG_LEVEL` | ❌ | `INFO` | Logging verbosity | `DEBUG`, `WARNING`, `ERROR` |
| `DEBUG` | ❌ | `false` | Enable debug mode | `true` |
| **⚡ Performance** |
| `WORKERS` | ❌ | `1` | Uvicorn worker processes | `4` |
| `MAX_CONCURRENT_REQUESTS` | ❌ | `100` | Request concurrency limit | `50` |

### Environment-Specific Examples

#### 🏠 **Development (.env)**
```bash
# Fast startup, verbose logging, local services
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
CHROMA_PERSIST_DIRECTORY=./chroma_db
DATABASE_URL=sqlite+aiosqlite:///./hras.db
LOG_LEVEL=DEBUG
DEBUG=true
```

#### 🏢 **Production (.env)**
```bash
# Secure, optimized, external services
OLLAMA_BASE_URL=http://ollama-service:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
CHROMA_PERSIST_DIRECTORY=/data/chromadb
DATABASE_URL=postgresql+asyncpg://hras_user:secure_password@postgres:5432/hras_db
CORS_ORIGINS=["https://hras.yourorg.com"]
LOG_LEVEL=WARNING
WORKERS=4
```

#### 🧪 **Testing (.env.test)**
```bash
# Isolated, predictable, fast
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
CHROMA_PERSIST_DIRECTORY=./test_chroma_db
DATABASE_URL=sqlite+aiosqlite:///./test.db
LOG_LEVEL=ERROR
```

---

## 🌐 Frontend Configuration (`frontend/.env.local`)

### Essential Settings

```bash
# 🔗 API Connection
NEXT_PUBLIC_API_URL=http://localhost:8000

# 🎛️ Feature Toggles
NEXT_PUBLIC_ENABLE_DEBUG=false
NEXT_PUBLIC_ANALYTICS_ID=
```

### Complete Variable Reference

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| **🔗 API** |
| `NEXT_PUBLIC_API_URL` | ✅ | `http://localhost:8000` | Backend API endpoint | `https://api.hras.yourorg.com` |
| **🎛️ Features** |
| `NEXT_PUBLIC_ENABLE_DEBUG` | ❌ | `false` | Show debug information | `true` |
| `NEXT_PUBLIC_ANALYTICS_ID` | ❌ | `` | Analytics tracking ID | `G-XXXXXXXXXX` |
| `NEXT_PUBLIC_VERSION` | ❌ | `0.2.0` | App version display | `v0.2.0-dev` |
| **🎨 UI** |
| `NEXT_PUBLIC_THEME` | ❌ | `light` | Default theme | `dark`, `auto` |
| `NEXT_PUBLIC_BRAND_NAME` | ❌ | `HRAS` | Application name | `Your Org HRAS` |

### Environment-Specific Examples

#### 🏠 **Development (.env.local)**
```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_ENABLE_DEBUG=true
NEXT_PUBLIC_THEME=auto
```

#### 🏢 **Production (.env.local)**
```bash
NEXT_PUBLIC_API_URL=https://api.hras.yourorg.com
NEXT_PUBLIC_ANALYTICS_ID=G-XXXXXXXXXX
NEXT_PUBLIC_THEME=light
NEXT_PUBLIC_BRAND_NAME="YourOrg Human Rights Advisory"
```

---

## ☸️ Kubernetes Configuration

### Configuration Pattern

HRAS uses **Kustomize overlays** following Ardan Labs patterns:

```
k8s/
├── base/           # Common configuration
│   ├── backend/    # Base backend manifests
│   └── frontend/   # Base frontend manifests
└── dev/            # Environment-specific overlays
    ├── backend/    # Dev backend patches
    └── frontend/   # Dev frontend patches
```

### Dev Environment ConfigMap

**`k8s/dev/backend/dev-backend-configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: hras-system
data:
  # Ollama configuration
  ollama_base_url: "http://host.docker.internal:11434"  # macOS/Windows
  # ollama_base_url: "http://172.17.0.1:11434"         # Linux alternative
  ollama_model: "nemotron-3-nano:30b-cloud"
  ollama_embedding_model: "nomic-embed-text"

  # Storage configuration
  chroma_persist_directory: "/app/chroma_db"
  database_url: "sqlite+aiosqlite:///./hras.db"

  # Network configuration
  cors_origins: '["http://localhost:3000"]'
  host: "0.0.0.0"
  port: "8000"

  # Logging
  log_level: "INFO"
  debug: "false"
```

### Production ConfigMap Template

**`k8s/prod/backend/prod-backend-configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: hras-system
data:
  # Production Ollama service
  ollama_base_url: "http://ollama-service.hras-system:11434"
  ollama_model: "nemotron-3-nano:30b-cloud"
  ollama_embedding_model: "nomic-embed-text"

  # Production storage
  chroma_persist_directory: "/data/chromadb"
  database_url: "postgresql+asyncpg://hras_user:${DB_PASSWORD}@postgres:5432/hras_db"

  # Production network
  cors_origins: '["https://hras.yourorg.com"]'

  # Production logging
  log_level: "WARNING"
  workers: "4"
```

---

## 🐳 Docker Configuration

### Docker Compose Environment

**`docker-compose.yml`** (with `.env` file):

```yaml
version: '3.8'
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
      - OLLAMA_MODEL=${OLLAMA_MODEL:-nemotron-3-nano:30b-cloud}
      - CHROMA_PERSIST_DIRECTORY=/app/chroma_db
    volumes:
      - ./backend/chroma_db:/app/chroma_db

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8000}
```

**`.env` for Docker Compose**:

```bash
# Shared configuration for docker-compose
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
API_URL=http://localhost:8000
```

---

## 🔧 Configuration Validation

### Automatic Validation

HRAS includes built-in configuration validation using **Pydantic Settings**:

```python
# backend/src/app/core/config.py
from pydantic import BaseSettings, validator

class Settings(BaseSettings):
    app_name: str = "HRAS"
    app_version: str = "0.2.0"

    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "nemotron-3-nano:30b-cloud"

    @validator('ollama_base_url')
    def validate_ollama_url(cls, v):
        if not v.startswith(('http://', 'https://')):
            raise ValueError('Ollama URL must start with http:// or https://')
        return v

    class Config:
        env_file = ".env"
        case_sensitive = False
```

### Manual Validation Script

**`scripts/validate-config.sh`**:

```bash
#!/bin/bash

echo "🔧 HRAS Configuration Validation"
echo "================================"

# Check backend configuration
echo "Backend configuration:"
cd backend
python -c "
from src.app.core.config import settings
print(f'✅ Ollama URL: {settings.ollama_base_url}')
print(f'✅ Model: {settings.ollama_model}')
print(f'✅ ChromaDB: {settings.chroma_persist_directory}')
"

# Test Ollama connectivity
echo -n "Ollama connectivity: "
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ OK" || echo "❌ FAIL"

# Check ChromaDB directory
echo -n "ChromaDB directory: "
[ -d "./chroma_db" ] && echo "✅ OK" || echo "⚠️  Will be created"

echo "Configuration validation complete!"
```

---

## 🔄 Configuration Management

### Development Workflow

1. **Copy Templates**:
   ```bash
   cp backend/.env.example backend/.env
   cp frontend/.env.local.example frontend/.env.local
   ```

2. **Edit for Your Environment**:
   ```bash
   # Edit backend configuration
   vi backend/.env

   # Edit frontend configuration
   vi frontend/.env.local
   ```

3. **Validate Configuration**:
   ```bash
   ./scripts/validate-config.sh
   ```

4. **Test Configuration**:
   ```bash
   make dev
   curl http://localhost:8000/health
   ```

### Production Deployment

1. **Secure Secrets Management**:
   ```bash
   # Use external secret management (not .env files)
   kubectl create secret generic hras-secrets \
     --from-literal=database-password=secure_password \
     --from-literal=ollama-api-key=api_key
   ```

2. **Environment-Specific ConfigMaps**:
   ```bash
   kubectl apply -k k8s/prod/backend/
   kubectl apply -k k8s/prod/frontend/
   ```

3. **Configuration Drift Detection**:
   ```bash
   # Compare actual vs expected config
   kubectl get configmap backend-config -o yaml
   ```

### Configuration Updates

#### Zero-Downtime Updates

```bash
# Update ConfigMap
kubectl patch configmap backend-config \
  --patch '{"data":{"log_level":"DEBUG"}}'

# Rolling restart to pick up changes
kubectl rollout restart deployment/backend
kubectl rollout status deployment/backend
```

#### Configuration Versioning

```bash
# Tag configuration changes
git add k8s/prod/backend/prod-backend-configmap.yaml
git commit -m "config: increase logging level for debugging"
git tag config-v1.2.0
```

---

## 🛡️ Security Best Practices

### Secrets Management

❌ **Never Do This**:
```bash
# DON'T commit secrets to git
echo "DATABASE_PASSWORD=secret123" >> .env
git add .env  # ❌ DANGEROUS
```

✅ **Do This Instead**:
```bash
# Use environment-specific secret management
export DATABASE_PASSWORD="secret123"

# Or use Kubernetes secrets
kubectl create secret generic db-secret \
  --from-literal=password=secret123
```

### Configuration Security Checklist

- [ ] **No secrets in git**: Use `.gitignore` for `.env` files
- [ ] **Environment isolation**: Separate configs per environment
- [ ] **Principle of least privilege**: Minimal required permissions
- [ ] **Regular rotation**: Update passwords and API keys regularly
- [ ] **Audit logging**: Track configuration changes
- [ ] **Encryption at rest**: Secure secret storage systems

### Environment Variable Security

```bash
# ✅ Good - using environment variables
export OLLAMA_API_KEY="sk-..."
./start-server.sh

# ❌ Bad - hardcoded in files
echo 'OLLAMA_API_KEY="sk-..."' > .env
```

---

## 🔍 Troubleshooting Configuration Issues

### Common Configuration Problems

#### 🚫 **"Ollama service unavailable"**

**Check**:
```bash
echo $OLLAMA_BASE_URL
curl $OLLAMA_BASE_URL/api/tags
```

**Fix**:
```bash
# Update URL to correct Ollama server
export OLLAMA_BASE_URL="http://localhost:11434"
```

#### 🚫 **"ChromaDB permission denied"**

**Check**:
```bash
ls -la $CHROMA_PERSIST_DIRECTORY
```

**Fix**:
```bash
# Create directory with correct permissions
mkdir -p ./chroma_db
chmod 755 ./chroma_db
```

#### 🚫 **"CORS origin not allowed"**

**Check**:
```bash
echo $CORS_ORIGINS
```

**Fix**:
```bash
# Add your frontend URL to CORS origins
export CORS_ORIGINS='["http://localhost:3000","https://your-frontend.com"]'
```

### Configuration Debugging

#### Enable Debug Mode

```bash
# Backend debug logging
export LOG_LEVEL=DEBUG
export DEBUG=true

# Frontend debug info
export NEXT_PUBLIC_ENABLE_DEBUG=true
```

#### Configuration Inspection

```bash
# View effective configuration
cd backend
python -c "
from src.app.core.config import settings
import json
print(json.dumps(settings.dict(), indent=2, default=str))
"
```

---

## 📚 Configuration Examples

### Scenario-Based Configuration

#### 🏠 **Local Development with External Ollama**
```bash
# backend/.env
OLLAMA_BASE_URL=http://192.168.1.100:11434
OLLAMA_MODEL=llama2:7b-chat
CHROMA_PERSIST_DIRECTORY=./chroma_db
LOG_LEVEL=DEBUG
```

#### ☁️ **Cloud Deployment with Managed Services**
```bash
# Production environment variables
OLLAMA_BASE_URL=https://ollama.cloud-provider.com
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
DATABASE_URL=postgresql://user:pass@managed-postgres:5432/hras
CHROMA_PERSIST_DIRECTORY=/data/chromadb
CORS_ORIGINS=["https://hras.yourorg.com"]
LOG_LEVEL=WARNING
```

#### 🧪 **CI/CD Pipeline Testing**
```bash
# .env.ci
OLLAMA_BASE_URL=http://test-ollama:11434
OLLAMA_MODEL=llama2:7b-chat
DATABASE_URL=sqlite+aiosqlite:///./test.db
CHROMA_PERSIST_DIRECTORY=./test_chroma
LOG_LEVEL=ERROR
```

This configuration reference provides everything you need to deploy and customize HRAS for your specific environment and requirements.
