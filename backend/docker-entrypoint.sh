#!/bin/sh
set -e

CHROMA_DIR="${CHROMA_PERSIST_DIRECTORY:-/app/chroma_db}"
mkdir -p "$CHROMA_DIR"
chown -R appuser:appuser "$CHROMA_DIR"

exec runuser -u appuser -- "$@"
