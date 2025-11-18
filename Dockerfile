# Stage 1: Build llama.cpp
FROM --platform=linux/arm64 ubuntu:24.04 AS builder

# 安裝 dependency
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libopenblas-dev \
    libcurl4-openssl-dev

WORKDIR /app

# Clone source 去 /app (即係 current directory)
# 咁樣做 structure 簡單啲，唔會有 /app/llama.cpp 呢層
RUN git clone --depth=1 https://github.com/ggerganov/llama.cpp.git .

# Compile
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build -j$(nproc) --config Release

# Stage 2: Runtime image
FROM --platform=linux/arm64 ubuntu:24.04 AS final

RUN apt-get update && apt-get install -y \
    libopenblas-dev \
    libcurl4 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# [修正重點]
# Source: 由於 WORKDIR 係 /app, build folder 係 /app/build
#         Binary 通常喺 build/bin 入面
# Dest:   直接 copy 去 /app/llama-server，簡單直接
COPY --from=builder /app/build/bin/llama-server /app/llama-server
# 如果你需要 CLI 版 (即係以前個 main)，可以 uncomment 下面呢行
# COPY --from=builder /app/build/bin/llama-cli /app/llama-cli

RUN chmod +x /app/llama-server

# Debug: 列出 /app 下面有咩，確保 copy 成功
RUN ls -la /app

ENTRYPOINT ["/app/llama-server"]
CMD ["-hf", "google/gemma-2b"]
