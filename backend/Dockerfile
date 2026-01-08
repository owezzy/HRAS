FROM python:3.13-slim AS base

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Dependencies stage - optimize for caching
FROM base AS deps

WORKDIR /app

# Copy dependency files first for better layer caching
COPY pyproject.toml ./
COPY uv.lock* ./
COPY README.md ./

# Install dependencies with uv caching
ENV UV_CACHE_DIR=/opt/uv-cache
RUN --mount=type=cache,target=/opt/uv-cache \
    uv sync --frozen --no-dev

# Production stage
FROM python:3.13-slim AS runner

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Copy virtual environment from deps stage
COPY --from=deps /app/.venv /app/.venv

# Copy only required dependency files
COPY pyproject.toml ./

# Copy application source code
COPY src/ ./src/
COPY agents/ ./agents/
COPY chains/ ./chains/
COPY tools/ ./tools/
COPY vectorstore/ ./vectorstore/
COPY prompts/ ./prompts/

# Expose port
EXPOSE 8000

# Run the application
CMD ["uv", "run", "uvicorn", "src.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
