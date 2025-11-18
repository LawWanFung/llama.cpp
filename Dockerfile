# Stage 1: Build llama.cpp
FROM --platform=linux/arm64 ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libopenblas-dev \
    libcurl4-openssl-dev
    # Add any other necessary dependencies for your specific llama.cpp build
    # e.g., if using Vulkan: libvulkan-dev

WORKDIR /app/llama.cpp
# RUN git clone https://github.com/ggerganov/llama.cpp .
COPY . .

# Compile llama.cpp
# Adjust CMake flags as needed for your specific ARM64 optimizations or features
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build -j$(nproc) --config Release

RUN ls -la

# Stage 2: Runtime image (optional, for smaller deployment)
FROM --platform=linux/arm64 ubuntu:24.04 As final

WORKDIR /app

RUN ls -la

# Copy compiled llama.cpp binaries and any required libraries
COPY --from=builder /app/llama.cpp/build/bin/main  /app/llama.cpp/main
# Copy any other necessary binaries or libraries
# Example: COPY --from=builder /usr/lib/aarch64-linux-gnu/libopenblas.so.0 /usr/lib/aarch64-linux-gnu/

# (Optional) Set entrypoint to run llama.cpp
ENTRYPOINT ["/app/llama.cpp/main"]
# CMD ["-m", "path/to/your/model.gguf", "-p", "Your prompt here"]
CMD ["./app/llama.cpp/main/llama-server", "-hf", "google/gemma-2b"]


