# HRAS - Configuration Reference

This document provides comprehensive reference for system configuration in the HRAS (Human Rights Advisory System).

## Configuration Philosophy

The HRAS system follows these configuration principles:

1. **Environment Variable Configuration:** All settings should be configurable via environment variables
2. **Separation of Concerns:** Different configuration contexts (development, staging, production) should be isolated
3. **Default Sensible Values:** Provide reasonable defaults that can be overridden
4. **Secrets Management:** Sensitive data should not be hardcoded
5. **Configuration Hierarchy:** Environment variables > command line args > defaults

## Configuration Sources

### 1. Environment Variables

All configuration is driven by environment variables. The following variables are supported:

#### Backend Configuration (.env file)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` | Yes |
| `OLLAMA_MODEL` | LLM model for chat | `nemotron-3-nano:30b-cloud` | Yes |
| `OLLAMA_EMBEDDING_MODEL` | Embedding model | `nomic-embed-text` | Yes |
| `CHROMA_PERSIST_DIRECTORY` | Vector store path | `./chroma_db` | Yes |
| `DATABASE_URL` | Database connection | `sqlite+aiosqlite:///./hras.db` | Yes |
| `CORS_ORIGINS` | Allowed origins | `["http://localhost:3000"]` | No |
| `REDIS_URL` | Redis cache URL | `redis://localhost:6379/0` | No |
| `LOG_LEVEL` | Logging level | `INFO` | No |

#### Frontend Configuration (.env.local file)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NEXT_PUBLIC_API_URL` | Backend API URL | `http://localhost:8000` | Yes |
| `NEXT_PUBLIC_FEATURE_FLAGS` | Feature flags | `{} ` | No |
| `NEXT_PUBLIC_ANALYTICS_ID` | Analytics tracking ID | `null` | No |

### 2. Configuration Hierarchy

Configuration follows this precedence (highest to lowest):

1. Environment variables
2. Command line arguments
3. Default values in code
4. Hardcoded fallbacks (not recommended)

### 3. Configuration Management Tools

- **dotenv:** For local development (.env files)
- **Kubernetes ConfigMaps:** For cluster configuration
- **Vault/Secrets Manager:** For production secrets
- **Consul/HCP:** For distributed configuration

## Configuration Files

### 1. Backend Configuration (.env.example)

```
# Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# Vector Store Configuration
CHROMA_PERSIST_DIRECTORY=./chroma_db

# Database Configuration
DATABASE_URL=sqlite+aiosqlite:///./hras.db

# Security Configuration
CORS_ORIGINS=["http://localhost:3000"]

# Feature Flags
ENABLE_FEATURE_X=true
FEATURE_Y_CONFIG=value
```

### 2. Frontend Configuration (.env.example)

```
# API Configuration
NEXT_PUBLIC_API_URL=http://localhost:8000

# Feature Configuration
NEXT_PUBLIC_ENABLE_FEATURE_A=true
NEXT_PUBLIC_FEATURE_B_ENDPOINT=https://api.example.com

# Analytics Configuration
NEXT_PUBLIC_ANALYTICS_ID=your-analytics-id
```

### 3. Kubernetes Configuration

The system uses Kubernetes ConfigMaps for environment-specific configuration:

#### Base Configuration (k8s/base/)
- Contains default configurations that apply to all environments
- Includes placeholder values for:
  - Image names
  - Default resource limits
  - Basic network configuration

#### Development Configuration (k8s/dev/)
- Overrides for development environment
- Includes:
  - Local database connections
  - Development-specific feature flags
  - Debug logging configuration
  - Hot reload settings

#### Production Configuration (k8s/prod/)
- Production-specific overrides
- Includes:
  - Production database connections
  - SSL/TLS configuration
  - Rate limiting settings
  - Cache expiration policies
  - Monitoring and alerting configuration

## Configuration Best Practices

### 1. Development Best Practices

1. **Use .env Files:** Keep sensitive configuration in .env files
2. **Never Commit Secrets:** Add .env files to .gitignore
3. **Use Sample Files:** Commit .env.example for reference
4. **Validate Configuration:** Use validation scripts to check required variables
5. **Environment Isolation:** Use separate configurations for different environments

### 2. Production Best Practices

1. **Secrets Management:** Use secure secrets management solutions
2. **Configuration Validation:** Implement runtime validation
3. **Configuration Auditing:** Regularly review configuration settings
4. **Immutable Configuration:** Treat configuration as immutable in production
5. **Version Control:** Track configuration changes alongside code changes

### 3. Configuration Validation

Implement runtime validation for required configuration:

```python
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    OLLAMA_BASE_URL: str = Field(default="http://localhost:11434")
    OLLAMA_MODEL: str = Field(default="nemotron-3-nano:30b-cloud")
    OLLAMA_EMBEDDING_MODEL: str = Field(default="nomic-embed-text")
    CHROMA_PERSIST_DIRECTORY: str = Field(default="./chroma_db")
    DATABASE_URL: str = Field(default="sqlite+aiosqlite:///./hras.db")
    CORS_ORIGINS: List[str] = Field(default=["http://localhost:3000"])
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

    def get_cors_origins(self) -> List[str]:
        """Convert comma-separated string to list."""
        return self.CORS_ORIGINS if isinstance(self.CORS_ORIGINS, list) else \
               [origin.strip() for origin in self.CORS_ORIGINS.split(',')]
        
settings = Settings()
```

### 4. Configuration Examples

#### Example: Loading Configuration in Python Backend

```python
# settings.py
from pydantic import BaseSettings

class Settings(BaseSettings):
    OLLAMA_BASE_URL: str
    OLLAMA_MODEL: str
    DATABASE_URL: str
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

#### Example: Using Configuration in Services

```python
# services/ingestion_service.py
from .config import settings

def get_chroma_path() -> str:
    """Get the ChromaDB path from configuration."""
    return settings.CHROMA_PERSIST_DIRECTORY

def get_ollama_base_url() -> str:
    """Get the Ollama base URL from configuration."""
    return settings.OLLAMA_BASE_URL
```

#### Example: Configuration in Docker

```dockerfile
# Dockerfile
ENV OLLAMA_BASE_URL=http://host.docker.internal:11434
ENV OLLAMA_MODEL=nemotron-3-nano:30b-cloud
ENV CHROMA_PERSIST_DIRECTORY=/app/chroma_db
```

## Environment-Specific Configuration

### 1. Development Configuration

- **Features:** Hot reload, debug logging, verbose output
- **Database:** SQLite (default)
- **Vector Store:** Local directory storage
- **External Services:** Local mocks or dev instances
- **Configuration Sources:**
  - `.env` files
  - Local environment variables
  - Development ConfigMaps

### 2. Testing Configuration

- **Isolation:** Completely isolated environment
- **Databases:** In-memory or test databases
- **External Services:** Mocked or test instances
- **Configuration Sources:**
  - Test-specific .env files
  - Test environment variables
  - Test ConfigMaps

### 3. Production Configuration

- **Features:** SSL termination, rate limiting, caching
- **Database:** Production-grade storage (e.g., PostgreSQL)
- **Vector Store:** Persistent, replicated storage
- **External Services:** Production-ready integrations
- **Configuration Sources:**
  - Secrets Manager
  - Production ConfigMaps
  - Environment variables from orchestration platform

## Configuration Migration Guide

### 1. Migrating from Hardcoded to Environment-Based Configuration

1. **Identify Hardcoded Values:** Search for literal values in code
2. **Create Environment Variable:** Map to corresponding environment variable
3. **Update Configuration Loader:** Ensure environment variables are loaded
4. **Test Migration:** Verify functionality with new configuration
5. **Document Changes:** Update documentation with migration instructions

### 2. Version Control Strategy

- **Configuration Versioning:** Track configuration changes alongside code
- **Migration Scripts:** Create scripts for configuration migrations
- **Backward Compatibility:** Maintain support for legacy configuration formats
- **Deprecation Policy:** Clearly communicate deprecation timelines

## Configuration Documentation Standards

1. **Clear Descriptions:** Each configuration option should have a clear description
2. **Default Values:** Document default values for all options
3. **Required vs Optional:** Clearly indicate required configuration
4. **Examples:** Provide example values for common use cases
5. **Dependencies:** Document relationships between configuration options
6. **Validation Rules:** Describe any validation or formatting requirements
7. **Security Notes:** Indicate security considerations for sensitive settings
8. **Migration Guidance:** Provide guidance for upgrading configuration formats