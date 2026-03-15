# 基础镜像：Rocky Linux 8 精简版
FROM rockylinux:8-minimal

# ===================== 标准化元数据 =====================
LABEL maintainer="tekintian <tekintian@gmail.com> (https://ai.tekin.cn)"
LABEL name="rockyLinux-llama.cpp-dev-env"
LABEL version="1.0.0"
LABEL release="dev"
LABEL summary="llama.cpp 开发容器（Rocky Linux 8）- 支持运行时可选编译"
LABEL description="基于 Rocky Linux 8 Minimal 构建的 llama.cpp 专属开发环境，集成 OpenBLAS 加速，适配 x86_64 架构，原生支持 GGUF 模型推理。"

# OCI 标准化元数据
LABEL org.opencontainers.image.authors="tekintian <tekintian@gmail.com> (https://ai.tekin.cn)"
LABEL org.opencontainers.image.source="https://github.com/tekintian/llama.cpp"
LABEL org.opencontainers.image.url="https://ai.tekin.cn/"
LABEL org.opencontainers.image.documentation="https://github.com/tekintian/llama.cpp/wiki"
LABEL org.opencontainers.image.title="Rocky Linux 8 llama.cpp 开发容器"
LABEL org.opencontainers.image.description="基于 Rocky Linux 8 Minimal 构建的 llama.cpp 专属开发环境，集成 OpenBLAS 数学库加速，适配 x86_64 通用架构，原生支持 GGUF 模型推理。"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="tekintian"
LABEL org.opencontainers.image.base.name="docker.io/library/rockylinux:8-minimal"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.ref.name="rockyLinux-llama.cpp-dev-env:1.0.0"
LABEL org.opencontainers.image.keywords="llama.cpp,RockyLinux8,OpenBLAS,GGUF,LLM,推理,开发容器"

# ===================== 环境配置 =====================
# 修复 locale 警告（先设置变量，再安装字符集包）
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    # 编译控制开关
    CONTROL_COMPILE=false

# ===================== 安装依赖（彻底适配 microdnf）=====================
RUN set -eux; \
    # 1. 先更新系统（可选，保证依赖最新）
    microdnf update -y; \
    # 2. 安装字符集包（解决 locale 警告）
    microdnf install -y glibc-langpack-en; \
    # 3. 兼容不同版本的 PowerTools repo 文件名，直接创建通用 repo 文件
    echo -e "[powertools]\nname=Rocky Linux 8 - PowerTools\nbaseurl=https://dl.rockylinux.org/pub/rocky/8/PowerTools/x86_64/os/\ngpgcheck=0\nenabled=1" > /etc/yum.repos.d/powertools.repo; \
    # 4. 安装开发/编译依赖（使用 microdnf 正确参数，移除 --nogpgcheck）
    microdnf install -y \
        # 核心编译工具
        gcc gcc-c++ cmake make git \
        # OpenBLAS 依赖
        openblas openblas-devel \
        # 系统依赖
        glibc-devel libstdc++-devel \
        # 常用工具
        which findutils vim less curl wget; \
    # 5. 创建工作目录
    mkdir -p /app /scripts; \
    # 6. 清理缓存（最小化镜像体积）
    microdnf clean all; \
    rm -rf /var/cache/yum/* /tmp/* /var/tmp/*; \
    # 7. 设置目录权限
    chmod 755 /app /scripts;

# ===================== 复制脚本 =====================
COPY build_llama_cpp.sh /scripts/
COPY entrypoint.sh /scripts/
RUN chmod +x /scripts/build_llama_cpp.sh /scripts/entrypoint.sh;

# ===================== 容器配置 =====================
# 暴露 llama-server 默认端口
EXPOSE 8080/tcp

# 设置工作目录
WORKDIR /app

# 健康检查（适配开发容器）
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD \
        if [ -f "/app/llama.cpp/build/bin/llama-server" ]; then \
            /app/llama.cpp/build/bin/llama-server --version >/dev/null 2>&1; \
        else \
            (gcc --version && cmake --version && pkg-config --exists openblas) >/dev/null 2>&1; \
        fi

# 入口点 + 默认命令
ENTRYPOINT ["/scripts/entrypoint.sh"]
CMD ["/bin/bash"]