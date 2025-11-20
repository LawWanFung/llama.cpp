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
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=OFF -DLLAMA_CURL=ON
RUN cmake --build build -j$(nproc) --config Release --clean-first 

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

ENV OMP_NUM_THREADS=4
ENV GOMP_CPU_AFFINITY=0-3


ENTRYPOINT ["/app/llama-server"]
# CMD ["-hf", "unsloth/gemma-3n-E4B-it-GGUF:Q4_K_M", "--host", "0.0.0.0", "--port", "8080"]

# Fastest, better than Q4_K_M
CMD ["--model", "google/gemma-3-12b-it-qat-q4_0-gguf:Q4_0","--model-draft", "/app/models/gemma-3-1b-it-q4_0.gguf", "--flash-attn","on","--draft-max","16","--draft-min","4", "--cache-type-k","q8_0","--cache-type-v","q8_0", "--jinja","--host", "0.0.0.0", "--port", "8080"] 

# Try 27B
# CMD ["--model", "/app/models/gemma-3-27b-it-q4_0.gguf","--model-draft", "/app/models/gemma-3-1b-it-q4_0.gguf", "--flash-attn","on","--draft-max","16","--draft-min","4", "--cache-type-k","q8_0","--cache-type-v","q8_0", "--jinja","--host", "0.0.0.0", "--port", "8080"] 

# NO! EVEN SLOWER THEN Q8_0
# CMD ["-hf", "unsloth/gemma-3-12b-it-GGUF:Q6_K", "--jinja","--host", "0.0.0.0", "--port", "8080"]

# The most accurate, 2.8token/s, no too slow but may not able to continue with long context
# CMD ["-hf", "unsloth/gemma-3-12b-it-GGUF:Q8_0", "--jinja","--host", "0.0.0.0", "--port", "8080"]

# CMD ["-hf", "ggml-org/gpt-oss-20b-GGUF", "--jinja","--host", "0.0.0.0", "--port", "8080"]
# CMD ["-hf", "unsloth/gpt-oss-20b-GGUF:Q4_K_S", "--jinja","--host", "0.0.0.0", "--port", "8080"]
