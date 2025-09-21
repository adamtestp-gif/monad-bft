# Stage 1: The "Cloud Forge" Workshop
# This stage is a powerful build environment. It has all the compilers and tools.
# It will be discarded at the end to keep our final product lean.
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install all build dependencies we painstakingly discovered.
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    clang \
    git \
    pkg-config \
    libssl-dev \
    libgmp-dev \
    libbrotli-dev \
    zlib1g-dev \
    libunwind-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory for the build
WORKDIR /usr/src/monad-bft

# Copy all the source code into the workshop
COPY . .

# Build the Monad node. This is the heavy lifting.
RUN cmake -DCMAKE_BUILD_TYPE=Release . && \
    make -j$(nproc) monad

# ---

# Stage 2: The Final, Clean Product
# This is the lightweight container we will ship to users.
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install ONLY the runtime dependencies. No compilers, no junk.
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libgmp-dev \
    libbrotli-dev \
    zlib1g-dev \
    libunwind-dev \
    && rm -rf /var/lib/apt/lists/*

# THIS IS THE CRITICAL FIX:
# Copy ONLY the final, compiled 'monad' program from the workshop stage
# and place it in a system directory where it can be run from anywhere.
COPY --from=builder /usr/src/monad-bft/build/monad /usr/local/bin/monad

# Expose the default RPC port
EXPOSE 8545

# This is the second critical fix:
# This command automatically runs when the container starts.
# Our users will no longer need to start it manually.
CMD ["monad"]