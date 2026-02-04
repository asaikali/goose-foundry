# cflinuxfs4 ≈ Ubuntu 22.04 (Jammy)
# Force amd64 so we build x86_64 binaries on Apple Silicon
FROM --platform=linux/amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUST_TOOLCHAIN=stable

# System dependencies commonly needed by Rust crates
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    build-essential \
    pkg-config \
    clang \
    cmake \
    make \
    perl \
    python3 \
    file \
  && rm -rf /var/lib/apt/lists/*

# Rust toolchain setup
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse \
    CARGO_INCREMENTAL=0

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y \
    --profile minimal \
    --default-toolchain ${RUST_TOOLCHAIN}

# Add Linux GNU target used for CF
RUN rustup target add x86_64-unknown-linux-gnu

WORKDIR /work

# Default command builds goosed for CF
CMD ["bash", "-lc", "cargo build -p goose-server --release --target x86_64-unknown-linux-gnu --bin goosed && file target/x86_64-unknown-linux-gnu/release/goosed"]