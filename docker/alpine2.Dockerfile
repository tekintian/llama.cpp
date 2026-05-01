# ======================== 阶段1：编译阶段（Alpine 3.19，完整编译环境） ========================
FROM tekintian/alpine:3.19 AS builder

# 核心参数：编译模式（static=静态库，shared=动态库），默认静态（体积更小）
ARG BUILD_MODE=static
# llama.cpp 版本（指定稳定版本，避免兼容性问题）
ARG LLAMA_VERSION=master

# 安装 Alpine 编译依赖（最小化）
RUN set -eux; \
    # 更新源并安装基础编译工具
    apk update && apk add --no-cache \
        git \
        cmake \
        make \
        g++ \
        gcc \
        openblas-dev \
        linux-headers \
        musl-dev \
        libstdc++ \
        pkgconf; \
    # 清理缓存（减小构建阶段体积）
    rm -rf /var/cache/apk/*

# 克隆 llama.cpp 源码（浅克隆，仅拉取最新代码）
RUN git clone --depth 1 --branch ${LLAMA_VERSION} https://github.com/tekintian/llama.cpp.git /app/llama.cpp; \
    cd /app/llama.cpp; \
    # 检出最新稳定标签（可选，保证版本可控）
    if [ $(git tag | wc -l) -gt 0 ]; then git checkout $(git describe --tags --abbrev=0); fi

# 编译 llama.cpp（适配 Alpine musl，禁用高版本指令集，保证兼容性）
WORKDIR /app/llama.cpp
RUN set -eux; \
    # 根据 BUILD_MODE 设置核心参数
    if [ "${BUILD_MODE}" = "shared" ]; then \
        SHARED_LIBS="ON"; \
        GGML_BACKEND_DL="ON"; \
    else \
        SHARED_LIBS="OFF"; \
        GGML_BACKEND_DL="OFF"; \
    fi; \
    # 清理旧构建目录
    rm -rf build && mkdir -p build; \
    # Alpine 适配的 CMake 配置
cmake -B build \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DGGML_ARCH=x86_64 \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_AVX=ON \
    -DGGML_AVX2=ON \
    -DGGML_FMA=ON \
    -DGGML_SSE3=ON \
    -DGGML_SSE4_1=ON \
    -DGGML_SSE4_2=ON \
    -DGGML_AVX512=OFF \
    -DGGML_AVX_VNNI=OFF \
    -DGGML_AMX=OFF \
    -DGGML_BLAS=OFF \
    # 体积优化：-Os 优化尺寸，-ffunction-sections 拆分函数段
    -DCMAKE_CXX_FLAGS="-Os -ffunction-sections -fdata-sections -fPIC" \
    -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -fPIC" \
    # Alpine musl 静态链接适配：移除 -static-libstdc++，保留 --gc-sections 清除未使用段
    -DCMAKE_EXE_LINKER_FLAGS="-static -Wl,--gc-sections,--strip-all" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections,--strip-all" \
    -DBUILD_SHARED_LIBS=${SHARED_LIBS} \
    -DGGML_BACKEND_DL=${GGML_BACKEND_DL}; \
    # 编译（多核心加速）
    cmake --build build -j$(nproc); \
    # 剥离可执行文件符号表（进一步减小体积）
    strip build/bin/llama-server build/bin/llama-cli; \
    # 验证编译结果
    if [ ! -f build/bin/llama-server ]; then echo "编译失败" && exit 1; fi

# ======================== 阶段2：运行阶段（极简 Alpine 镜像） ========================
FROM tekintian/alpine:3.19

# 复制编译产物（仅复制必要文件，最小化体积）
COPY --from=builder --chown=llama:llama /app/llama.cpp/build/bin/llama-server /app/

# 安装运行依赖（仅保留必要库）
RUN set -eux; \
    apk add --no-cache \
        libgomp \
        libstdc++ \
        ca-certificates \
        wget; \
    rm -rf /var/cache/apk/*

# 创建非 root 用户（安全最佳实践）
RUN addgroup -S llama && adduser -S llama -G llama -h /app

# ===== 最终修复：完全适配 ash 的启动脚本 =====
RUN printf '#!/bin/ash\n\
set -euo pipefail\n\
\n\
# 设置默认值（ash 兼容写法）\n\
LLAMA_HOST=${LLAMA_HOST:-0.0.0.0}\n\
LLAMA_PORT=${LLAMA_PORT:-8080}\n\
LLAMA_CTX_SIZE=${LLAMA_CTX_SIZE:-2048}\n\
LLAMA_MODEL=${LLAMA_MODEL:-}\n\
LLAMA_EXTRA_ARGS=${LLAMA_EXTRA_ARGS:-}\n\
\n\
# 构建基础参数（用字符串拼接，ash 兼容）\n\
LLAMA_ARGS="--host $LLAMA_HOST --port $LLAMA_PORT --ctx-size $LLAMA_CTX_SIZE"\n\
\n\
# 如果指定了模型路径，添加到参数中\n\
if [ -n "$LLAMA_MODEL" ]; then\n\
    LLAMA_ARGS="$LLAMA_ARGS --model $LLAMA_MODEL"\n\
fi\n\
\n\
# 如果有额外参数，添加进去\n\
if [ -n "$LLAMA_EXTRA_ARGS" ]; then\n\
    LLAMA_ARGS="$LLAMA_ARGS $LLAMA_EXTRA_ARGS"\n\
fi\n\
\n\
# 打印参数（调试用）\n\
echo "Starting llama-server with args: $LLAMA_ARGS"\n\
\n\
# 最终修复：直接用 sh -c 执行，避免 eval 找不到的问题\n\
exec /bin/sh -c "/app/llama-server $LLAMA_ARGS"\n' > /app/start.sh && \
    chmod +x /app/start.sh && \
    chown llama:llama /app/start.sh

# 工作目录
WORKDIR /app
USER llama

# 环境变量默认值
ENV LLAMA_HOST=0.0.0.0 \
    LLAMA_PORT=8080 \
    LLAMA_CTX_SIZE=2048 \
    LLAMA_MODEL="" \
    LLAMA_EXTRA_ARGS=""

# 暴露 llama-server 端口（默认 8080）
EXPOSE ${LLAMA_PORT:-8080}

# 健康检查（动态端口，ash 兼容）
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD wget -q -O - http://localhost:${LLAMA_PORT:-8080}/health || exit 1

# 使用启动脚本作为入口点
ENTRYPOINT ["/app/start.sh"]