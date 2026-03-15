# 全局定义构建参数（默认值+传递到所有阶段）
ARG LLAMA_VERSION=master

# ======================== 阶段1：编译阶段（Alpine 3.19，完整编译环境） ========================
FROM tekintian/alpine:3.19 AS builder

# 核心参数：
# 1. BUILD_MODE：static/shared（库类型）  --build-arg LLAMA_VERSION=static
ARG BUILD_MODE=static
# 2. 版本信息 可以在构建是指定修改 --build-arg LLAMA_VERSION=master
ARG LLAMA_VERSION

LABEL maintainer="tekintian <tekintian@gmail.com>"
LABEL name="llama-server"
LABEL version="${LLAMA_VERSION}"

# 安装 Alpine 编译依赖（包含 OpenBLAS 开发包）
RUN set -eux; \
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
    rm -rf /var/cache/apk/*

# 克隆 llama.cpp 源码（浅克隆，减小构建体积）
RUN git clone --depth 1 --branch ${LLAMA_VERSION} https://github.com/tekintian/llama.cpp.git /app/llama.cpp; \
    cd /app/llama.cpp; \
    # 检出最新稳定标签（可选，保证版本可控）
    if [ $(git tag | wc -l) -gt 0 ]; then git checkout $(git describe --tags --abbrev=0); fi

# 编译 llama.cpp（适配 Alpine musl，启用 OpenBLAS 加速）
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
    # Alpine 适配的 CMake 配置（启用 OpenBLAS）
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
        -DGGML_BLAS=ON \
        -DGGML_BLAS_VENDOR=OpenBLAS \
        -DCMAKE_CXX_FLAGS="-Os -ffunction-sections -fdata-sections -fPIC" \
        -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -fPIC" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,--gc-sections,--strip-all" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections,--strip-all" \
        -DBUILD_SHARED_LIBS=${SHARED_LIBS} \
        -DGGML_BACKEND_DL=${GGML_BACKEND_DL}; \
    # 编译（多核心加速）
    cmake --build build -j$(nproc); \
    # 剥离符号表，减小体积
    strip build/bin/llama-server build/bin/llama-cli; \
    # 验证编译结果（根据类型检查对应二进制）
    if [ ! -f build/bin/llama-server ]; then echo "编译失败" && exit 1; fi

# ======================== 阶段2：运行阶段 - Server 版本（极简镜像） ========================
FROM tekintian/alpine:3.19 AS runtime-server
ARG LLAMA_VERSION
# 基础维护者信息
LABEL maintainer="tekintian <tekintian@gmail.com>"
LABEL name="llama-server"
LABEL version="${LLAMA_VERSION}"

# OCI 标准化元信息（兼容主流容器平台）
LABEL org.opencontainers.image.authors="tekintian <tekintian@gmail.com> (https://ai.tekin.cn)"
LABEL org.opencontainers.image.source="https://github.com/tekintian/llama.cpp"
LABEL org.opencontainers.image.url="https://ai.tekin.cn/"
LABEL org.opencontainers.image.documentation="https://github.com/tekintian/llama.cpp/wiki"
LABEL org.opencontainers.image.title="llama-server (Alpine)"
LABEL org.opencontainers.image.description="轻量级 llama.cpp 服务端镜像，基于 Alpine 3.19 构建，集成 OpenBLAS 加速，默认静态编译最小体积优化。适配 x86_64 通用架构，支持 GGUF 模型推理，提供 HTTP API 服务，开箱即用且体积精简。"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${LLAMA_VERSION}"
LABEL org.opencontainers.image.vendor="tekintian"
LABEL org.opencontainers.image.base.name="tekintian/alpine:3.19"
# 镜像分类标签（便于检索）
LABEL org.opencontainers.image.keywords="llama.cpp,LLM,GGUF,Alpine,OpenBLAS,x86_64,AI推理,轻量级"

# 安装运行依赖（包含 OpenBLAS 运行库）
RUN set -eux; \
    apk add --no-cache \
        libgomp \
        libstdc++ \
        ca-certificates \
        wget \
        openblas \
        lapack; \
    rm -rf /var/cache/apk/*

# 创建非 root 用户
RUN addgroup -S llama && adduser -S llama -G llama -h /app

# 复制编译好的 llama-server
COPY --from=builder --chown=llama:llama /app/llama.cpp/build/bin/llama-server /app/

# Server 专属：启动脚本（ash 兼容）
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

WORKDIR /app
USER llama
ENV LLAMA_HOST=0.0.0.0 \
    LLAMA_PORT=8080 \
    LLAMA_CTX_SIZE=2048 \
    LLAMA_MODEL="" \
    LLAMA_EXTRA_ARGS=""

EXPOSE ${LLAMA_PORT:-8080}
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
    CMD wget -q -O - http://localhost:${LLAMA_PORT:-8080}/health || exit 1
ENTRYPOINT ["/app/start.sh"]
