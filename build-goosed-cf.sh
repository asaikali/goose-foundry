#!/bin/bash
set -euo pipefail

# Build goosed for Linux x86_64 using the repo Dockerfile image (Ubuntu 22.04).
# Output: target/linux-release/release/goosed

IMAGE_TAG="goose-build:cf"
LINUX_TARGET="target/linux-release"

# Clean stale build artifacts to avoid glibc mismatch with cached build scripts.
rm -rf "$LINUX_TARGET"
mkdir -p "$LINUX_TARGET"

# Build the image from the repo Dockerfile
docker build --platform linux/amd64 -t "$IMAGE_TAG" .

# Build goosed inside the image
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)":/src \
  -w /src/vendor/goose \
  -e CARGO_TARGET_DIR=/src/target/linux-release \
  "$IMAGE_TAG" \
  bash -lc "cargo build --release --bin goosed"

BINARY="$LINUX_TARGET/release/goosed"
echo ""
file "$BINARY"
docker run --rm \
  --platform linux/amd64 \
  -v "$(pwd)":/src \
  ubuntu:22.04 \
  ldd "/src/$BINARY"
