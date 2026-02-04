#!/usr/bin/env bash
set -euo pipefail

# setup-toolchain.sh
# Build a Rust toolchain image for Cloud Foundry (cflinuxfs4-ish) on macOS,
# forcing linux/amd64 so it’s x86_64 even on Apple Silicon (M1/M2).
#
# Usage:
#   ./setup-toolchain.sh
#
# Optional env vars:
#   IMAGE_NAME=goose-cf-build
#   DOCKERFILE=Dockerfile.cflinuxfs4-rust
#   PLATFORM=linux/amd64
#   BUILDER_NAME=goose-amd64-builder
#   RUST_TOOLCHAIN=stable   (passed as build-arg if your Dockerfile supports it)

IMAGE_NAME="${IMAGE_NAME:-goose-cf-build}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"
BUILDER_NAME="${BUILDER_NAME:-goose-amd64-builder}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"

die() { echo "ERROR: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

echo "==> Checking prerequisites"
need_cmd docker

docker info >/dev/null 2>&1 || die "Docker daemon not reachable. Is Docker Desktop running?"
docker buildx version >/dev/null 2>&1 || die "docker buildx not available. Update Docker Desktop."

[[ -f "${DOCKERFILE}" ]] || die "Dockerfile not found: ${DOCKERFILE}"

echo "==> Ensuring buildx builder exists: ${BUILDER_NAME}"
if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
  docker buildx create --name "${BUILDER_NAME}" --use >/dev/null
else
  docker buildx use "${BUILDER_NAME}" >/dev/null
fi

echo "==> Bootstrapping builder (QEMU for ${PLATFORM} on Apple Silicon)"
docker buildx inspect --bootstrap >/dev/null

echo "==> Building image '${IMAGE_NAME}' from '${DOCKERFILE}' for platform '${PLATFORM}'"
# --load ensures the resulting image is available to plain `docker run`
docker buildx build \
  --platform "${PLATFORM}" \
  --build-arg RUST_TOOLCHAIN="${RUST_TOOLCHAIN}" \
  -t "${IMAGE_NAME}" \
  -f "${DOCKERFILE}" \
  --load \
  .

echo "==> Verifying image"
docker run --rm --platform "${PLATFORM}" "${IMAGE_NAME}" bash -lc 'echo "arch=$(uname -m)"; rustc -V; cargo -V'

cat <<EOF

Done.

Example build (from your repo root):
  docker run --rm -it --platform ${PLATFORM} \\
    -v "\$PWD":/work -w /work \\
    ${IMAGE_NAME} \\
    bash -lc 'cargo build -p goose-server --release --target x86_64-unknown-linux-gnu --bin goosed'

EOF
