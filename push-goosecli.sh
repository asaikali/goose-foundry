#!/bin/bash
set -euo pipefail

# Push goose CLI web to Cloud Foundry.
# Usage: ./push-goosecli.sh
# Requires OPENAI_API_KEY to be set in your shell environment.
#
# Run ./build-goose first to cross-compile the Linux x86_64 binaries.

APP_DIR="apps/goosecli"
BINARY="target/linux-release/release/goose"
STAGE_DIR="${APP_DIR}/stage"
MANIFEST="${APP_DIR}/manifest.yml"
PROCFILE="${APP_DIR}/Procfile"

# --- Sanity checks ---

if ! command -v cf >/dev/null 2>&1; then
  echo "Error: cf CLI not found in PATH"
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "Error: OPENAI_API_KEY is not set"
  exit 1
fi


if [ ! -f "$MANIFEST" ]; then
  echo "Error: $MANIFEST not found"
  echo "Add one that sets the binary_buildpack and env vars."
  exit 1
fi

if [ ! -f "$BINARY" ]; then
  echo "Error: Binary not found at $BINARY"
  echo "Run ./build-goose first."
  exit 1
fi

if ! file "$BINARY" | grep -q "ELF 64-bit LSB"; then
  echo "Error: $BINARY is not a Linux ELF binary."
  echo "Rebuild with ./build-goose (uses Docker)."
  exit 1
fi

# --- Stage app directory ---

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

cp "$BINARY" "$STAGE_DIR/goose"
chmod +x "$STAGE_DIR/goose"

cp "$PROCFILE" "$STAGE_DIR/Procfile"

echo "Staging directory contents:"
ls -lah "$STAGE_DIR"

# --- Push ---

cf push -f "$MANIFEST" -p "$STAGE_DIR" \
  --var OPENAI_API_KEY="$OPENAI_API_KEY"
