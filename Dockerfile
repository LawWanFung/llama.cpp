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
RUN git clone --depth=1 https://github.com/ggerganov/llama.cpp.git .

# Compile
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build -j$(nproc) --config Release

# Stage 2: Runtime image
FROM --platform=linux/arm64 ubuntu:24.04 AS final

# [修正] 安裝 Runtime 必須嘅 Library
# libgomp1: OpenMP 多線程必須 (最常見缺呢個)
# libopenblas0: OpenBLAS Runtime (唔駛裝 -dev 版)
# libcurl4: Curl Runtime
RUN apt-get update && apt-get install -y \
    libopenblas0 \
    libgomp1 \
    libcurl4 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Binary
COPY --from=builder /app/build/bin/llama-server /app/llama-server
# COPY --from=builder /app/build/bin/llama-cli /app/llama-cli

RUN chmod +x /app/llama-server

# Debug: 檢查一下 Binary 缺咩 Library (如果 build fail 可以睇 log)
RUN ldd /app/llama-server || echo "ldd failed, maybe strictly static?"

ENTRYPOINT ["/app/llama-server"]
CMD ["-hf", "google/gemma-2b"]
