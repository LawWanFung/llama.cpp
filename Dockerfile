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

# Clone source 去 /app
RUN git clone --depth=1 https://github.com/ggerganov/llama.cpp.git .

# Compile
# -DBUILD_SHARED_LIBS=ON 係預設，所以會產生 .so 檔
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build -j$(nproc) --config Release

# Stage 2: Runtime image
FROM --platform=linux/arm64 ubuntu:24.04 AS final

# 安裝 Runtime 必須嘅 Library
RUN apt-get update && apt-get install -y \
    libopenblas0 \
    libgomp1 \
    libcurl4 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# [修正重點] 1. Copy 執行檔
COPY --from=builder /app/build/bin/llama-server /app/llama-server

# [修正重點] 2. Copy 埋所有 compile 出黎嘅 shared library (.so) 
# 放入 /usr/lib/ 系統路徑，咁就唔駛 set LD_LIBRARY_PATH
COPY --from=builder /app/build/bin/*.so* /usr/lib/

# [修正重點] 3. 刷新一下 library cache，確保系統認到新加嘅 library
RUN ldconfig

RUN chmod +x /app/llama-server

# Debug: 再 Check 多次，今次應該會見到全部 found
RUN ldd /app/llama-server || echo "ldd failed"

ENTRYPOINT ["/app/llama-server"]
# CMD ["-hf", "unsloth/gemma-3n-E4B-it-GGUF:Q4_K_M", "--host", "0.0.0.0", "--port", "8080"]
CMD ["-hf", "google/gemma-7b", "--host", "0.0.0.0", "--port", "8080"]
