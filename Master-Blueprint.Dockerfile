# Stage 1: The "Cloud Forge" Workshop V4 - DIAGNOSTIC RUN
# This version's sole purpose is to show us the ground truth of the file system.
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies.
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

# Change directory into the actual source code location.
WORKDIR /usr/src/monad-ws/monad-bft

# --- THIS IS THE CAMERA ---
# List the contents of the current directory to see if CMakeLists.txt is here.
# The build will FAIL after this, which is INTENTIONAL.
RUN ls -laR

# This is the original build command. We expect it to fail again, but after giving us the file list.
RUN cmake -DCMAKE_BUILD_TYPE=Release . && \
    make -j4 monad

# ---

# Stage 2: The Final, Clean Product (Will not be reached in this run)
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y libssl-dev libgmp-dev libbrotli-dev zlib1g-dev libunwind-dev && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/monad-ws/monad-bft/build/monad /usr/local/bin/monad
EXPOSE 8545
CMD ["monad"]