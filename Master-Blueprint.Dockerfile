# Stage 1: The "Cloud Forge" Workshop V3 - Definitive Build
# This version is robust and corrects all previous pathing and resource issues.
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install a more comprehensive list of build dependencies to ensure stability.
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
    libgtest-dev \
    libgoogle-glog-dev \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set the parent working directory
WORKDIR /usr/src/monad-ws

# Copy all the source code into the workshop
COPY . .

# THIS IS THE CRITICAL PATH FIX:
# Change directory into the actual source code location before building.
WORKDIR /usr/src/monad-ws/monad-bft

# THIS IS THE CRITICAL BUILD FIX:
# Run cmake and then run 'make' with a limited number of jobs (-j4) to prevent RAM exhaustion.
RUN cmake -DCMAKE_BUILD_TYPE=Release . && \
    make -j4 monad

# ---

# Stage 2: The Final, Clean Product
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install ONLY the runtime dependencies.
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libgmp-dev \
    libbrotli-dev \
    zlib1g-dev \
    libunwind-dev \
    && rm -rf /var/lib/apt/lists/*

# THIS IS THE CRITICAL COPY FIX:
# Copy the compiled program from the correct, nested build path in the workshop stage
# and place it where it can be globally executed.
COPY --from=builder /usr/src/monad-ws/monad-bft/build/monad /usr/local/bin/monad

# Expose the default RPC port
EXPOSE 8545

# The self-starting command for the node.
CMD ["monad"]