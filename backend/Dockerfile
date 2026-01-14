FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

WORKDIR /app

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=README.md,target=README.md \
    uv sync --frozen --no-install-project --no-dev

COPY src/ ./src/
COPY agents/ ./agents/
COPY chains/ ./chains/
COPY tools/ ./tools/
COPY vectorstore/ ./vectorstore/
COPY prompts/ ./prompts/
COPY pyproject.toml uv.lock README.md ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

FROM python:3.12-slim-bookworm

RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser appuser && \
    mkdir -p /data && chown appuser:appuser /data

COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv

WORKDIR /app

COPY --chown=appuser:appuser src/ ./src/
COPY --chown=appuser:appuser agents/ ./agents/
COPY --chown=appuser:appuser chains/ ./chains/
COPY --chown=appuser:appuser tools/ ./tools/
COPY --chown=appuser:appuser vectorstore/ ./vectorstore/
COPY --chown=appuser:appuser prompts/ ./prompts/

ENV PATH="/app/.venv/bin:$PATH"
ENV HOME=/home/appuser
ENV PYTHONPATH=/app

USER appuser

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "src.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
