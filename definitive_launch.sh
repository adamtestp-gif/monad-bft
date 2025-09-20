#!/bin/bash
set -e

# ====================================================================
# HYPERSCOPELABS - DEFINITIVE MONAD SANDBOX LAUNCHER V1.0
# ====================================================================

echo "### PHASE 1: FORGING ARTIFACTS ###"

# Define our pre-compiled workshop and a local folder for the finished parts
BUILDER_IMAGE="ghcr.io/adamtestp-gif/monad-sandbox:latest"
ARTIFACTS_DIR="$PWD/_artifacts"
mkdir -p "$ARTIFACTS_DIR"

echo "--> Pulling our pre-built Workshop image..."
docker pull "$BUILDER_IMAGE"

echo "--> Entering Workshop to compile Monad binaries..."
# We enter the workshop, sharing our source code and the empty artifacts folder.
# Inside, we run the C++ compilation and then copy the finished programs into the artifacts folder.
docker run --rm -it -u root \
  -v "$PWD":/monad-bft \
  -v "$ARTIFACTS_DIR":/artifacts \
  --workdir /monad-bft/monad-cxx/monad-execution \
  "$BUILDER_IMAGE" \
  bash -c " \
    apt-get update > /dev/null && apt-get install -y --no-install-recommends libgmock-dev libbrotli-dev libcrypto++-dev > /dev/null && \
    git config --global --add safe.directory /monad-bft && \
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc-15 -DCMAKE_CXX_COMPILER=g++-15 && \
    cmake --build build --target monad monad_cli monad_mpt -- -j$(nproc) && \
    cp build/cmd/monad /artifacts/monad && \
    cp build/cmd/monad_cli /artifacts/monad_cli && \
    cp build/category/mpt/monad_mpt /artifacts/monad_mpt \
  "

echo "--> Forging complete. Binaries are in '$ARTIFACTS_DIR'."


echo "### PHASE 2: BUILDING LIGHTWEIGHT RUNTIME IMAGES ###"

# Create a simple blueprint for our final node. It just copies the pre-built program.
cat > Dockerfile.monad-node << EOF
FROM docker.io/ubuntu:25.04
COPY monad /usr/local/bin/monad
COPY monad_cli /usr/local/bin/monad_cli
COPY monad_mpt /usr/local/bin/monad_mpt
# This blueprint needs its own tools, but they are lightweight
RUN apt-get update && apt-get install -y --no-install-recommends binutils iproute2 clang curl make ca-certificates libssl3t64 libboost-atomic1.83.0 libboost-container1.83.0 libboost-fiber1.83.0 libboost-filesystem1.83.0 libboost-graph1.83.0 libboost-json1.83.0 libboost-regex1.83.0 libboost-stacktrace1.83.0 && rm -rf /var/lib/apt/lists/*
EOF

echo "--> Building final hyperscope-monad-node image..."
docker build -t hyperscope/monad-node:latest -f Dockerfile.monad-node "$ARTIFACTS_DIR"


echo "### PHASE 3: LAUNCHING THE NETWORK ###"

# Create the small override file to use our new, lightweight image
cat > docker/single-node/nets/override.yaml << EOF
services:
  build_triedb:
    image: hyperscope/monad-node:latest
    command: monad_mpt --storage /monad/triedb/test.db --create
  build_genesis:
    image: hyperscope/monad-node:latest
    command: monad --chain monad_devnet --db /monad/triedb/test.db --block_db /monad/ledger --nblocks 0
  monad_execution:
    image: hyperscope/monad-node:latest
    command: monad --chain monad_devnet --db /monad/triedb/test.db --block_db /monad/ledger --statesync /monad/statesync.sock
EOF

echo "--> Launching private network with docker-compose..."
cd docker/single-node/nets

# We must still create the .env file for the official compose to work
export MONAD_BFT_ROOT=$(realpath ../../..)
export DEVNET_DIR=$(realpath ../../../docker/devnet)
export RPC_DIR=$(realpath ../../../docker/rpc)
echo "MONAD_BFT_ROOT=${MONAD_BFT_ROOT}" > .env
echo "DEVNET_DIR=${DEVNET_DIR}" >> .env
echo "RPC_DIR=${RPC_DIR}" >> .env

# Launch using the main compose file AND our override file
docker compose -f compose.yaml -f override.yaml up --build -d

echo "### VICTORY! Your private Monad network is running. ###"
echo "Check status with: docker ps"
