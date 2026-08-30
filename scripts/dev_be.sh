#!/usr/bin/env bash
set -e

# Resolve repository root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BE_DIR="$ROOT_DIR/snape_be"
VENV_DIR="$BE_DIR/.venv"

# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$BE_DIR/requirements.txt"
fi

cd "$BE_DIR"
echo "Starting Snape Backend on http://localhost:8000 (docs: http://localhost:8000/api/v1/docs)..."
exec "$VENV_DIR/bin/uvicorn" app.main:app --reload --host 0.0.0.0 --port 8000 "$@"
