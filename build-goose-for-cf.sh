#!/bin/bash
set -euo pipefail

# Build goosed + goose CLI for Linux x86_64 using the repo Dockerfile image (Ubuntu 22.04).
# Output: target/linux-release/release/goosed and target/linux-release/release/goose

IMAGE_TAG="goose-build:cf"
LINUX_TARGET="target/linux-release"

# Clean stale build artifacts to avoid glibc mismatch with cached build scripts.
rm -rf "$LINUX_TARGET"
mkdir -p "$LINUX_TARGET"

# Build the image from the repo Dockerfile
docker build --platform linux/amd64 -t "$IMAGE_TAG" .

# Build goosed + goose inside the image
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)":/src \
  -w /src/vendor/goose \
  -e CARGO_TARGET_DIR=/src/target/linux-release \
  "$IMAGE_TAG" \
  bash -lc "cargo build --release --package goose-server --bin goosed && cargo build --release --package goose-cli --bin goose"

GOOSED_BIN="$LINUX_TARGET/release/goosed"
GOOSE_BIN="$LINUX_TARGET/release/goose"
echo ""
file "$GOOSED_BIN"
file "$GOOSE_BIN"
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)":/src \
  ubuntu:22.04 \
  ldd "/src/$GOOSED_BIN"
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)":/src \
  ubuntu:22.04 \
  ldd "/src/$GOOSE_BIN"
