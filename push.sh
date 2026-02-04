#!/bin/bash
set -euo pipefail

# Push goosed to Cloud Foundry.
# Usage: ./push.sh
# Requires OPENAI_API_KEY to be set in your shell environment.
#
# Run ./build-goosed-cf.sh first to cross-compile the Linux x86_64 binary.

BINARY="target/linux-release/release/goosed"
STAGE_DIR="cf-app"

# --- Sanity checks ---

if ! command -v cf >/dev/null 2>&1; then
  echo "Error: cf CLI not found in PATH"
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "Error: OPENAI_API_KEY is not set"
  exit 1
fi

if [ ! -f "manifest.yml" ]; then
  echo "Error: manifest.yml not found in repo root"
  echo "Add one that sets the binary_buildpack and env vars."
  exit 1
fi

if [ ! -f "$BINARY" ]; then
  echo "Error: Binary not found at $BINARY"
  echo "Run ./build-goosed-cf.sh first."
  exit 1
fi

if ! file "$BINARY" | grep -q "ELF 64-bit LSB"; then
  echo "Error: $BINARY is not a Linux ELF binary."
  echo "Rebuild with ./build-goosed-cf.sh (uses Docker)."
  exit 1
fi

# --- Stage app directory ---

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

cp "$BINARY" "$STAGE_DIR/goosed"
chmod +x "$STAGE_DIR/goosed"

cat > "$STAGE_DIR/Procfile" <<'EOF'
web: GOOSE_HOST=0.0.0.0 GOOSE_PORT=$PORT ./goosed agent
EOF

echo "Staging directory contents:"
ls -lah "$STAGE_DIR"

# --- Push ---

cf push -p "$STAGE_DIR" --var OPENAI_API_KEY="$OPENAI_API_KEY"
