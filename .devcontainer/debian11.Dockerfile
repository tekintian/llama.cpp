# 基于 Docker Dev Environments 默认的 Debian 11 镜像
FROM debian:11

LABEL maintainer="tekintian <tekintian@gmail.com>"

# 切换到 root 安装软件（容器内安装软件需要 root 权限）
USER root

# 第一步：先用官方 HTTP 源安装证书（避免 HTTPS 证书验证失败）
RUN echo "deb http://deb.debian.org/debian bullseye main non-free contrib" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye-updates main non-free contrib" >> /etc/apt/sources.list && \
    # 安装核心依赖（含证书）
    apt update && apt install -y --no-install-recommends \
    wget bzip2 git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 第二步：证书安装完成后，切换为阿里云 HTTPS 源（可选，加速后续安装）
RUN echo "deb https://mirrors.aliyun.com/debian/ bullseye main non-free contrib" > /etc/apt/sources.list && \
    echo "deb https://mirrors.aliyun.com/debian-security/ bullseye-security main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib" >> /etc/apt/sources.list && \
    apt update && rm -rf /var/lib/apt/lists/*

# 安装 Miniconda（给普通用户授权）
RUN set -eux; \
    mkdir -p /home/vscode && chown -R 1000:1000 /home/vscode && \
    # 下载 Miniconda（添加超时和校验，避免下载失败）
    wget --timeout=30 --no-check-certificate https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    # 静默安装
    bash /tmp/miniconda.sh -b -p /usr/local/miniconda3 && \
    rm /tmp/miniconda.sh && \
    # 给普通用户（UID 1000，Docker Dev Environments 默认）授权
    chown -R 1000:1000 /usr/local/miniconda3 && \
    # 配置 Conda 镜像源（清华镜像，清理默认源避免冲突）
    /usr/local/miniconda3/bin/conda config --remove-key channels && \
    /usr/local/miniconda3/bin/conda config --set show_channel_urls True && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2 && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda && \
    # 清理 conda 缓存
    /usr/local/miniconda3/bin/conda clean -i -y

# 切换回普通用户（避免权限问题）
USER 1000
# 确保普通用户家目录存在并授权
ENV HOME=/home/vscode

# 配置 Conda 环境变量（普通用户生效，确保优先级）
ENV PATH="/usr/local/miniconda3/bin:${PATH}"

# 验证安装（捕获错误，构建失败时明确提示）
RUN conda --version || (echo "Conda 安装失败" && exit 1) && \
    pip3 --version || (echo "pip3 安装失败" && exit 1)
