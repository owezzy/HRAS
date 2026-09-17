FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

COPY pyproject.toml uv.lock README.md ./
RUN uv sync --frozen --no-install-project --no-dev

COPY src/ ./src/
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.12-slim-bookworm

RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser appuser

COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv

WORKDIR /app

COPY --chown=appuser:appuser src/ ./src/
COPY --chown=appuser:appuser alembic.ini ./alembic.ini
COPY --chown=appuser:appuser alembic/ ./alembic/

ENV PATH="/app/.venv/bin:$PATH"
ENV HOME=/home/appuser
ENV PYTHONPATH=/app
ENV PORT=8000

RUN mkdir -p /app/chroma_db && chown -R appuser:appuser /app/chroma_db

USER appuser

EXPOSE 8000

CMD ["sh", "-c", "python -m uvicorn src.app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
