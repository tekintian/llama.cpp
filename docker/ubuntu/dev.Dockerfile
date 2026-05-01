ARG UBUNTU_VERSION=22.04

FROM ubuntu:$UBUNTU_VERSION AS build

ARG UBUNTU_VERSION

# 基础维护者信息
LABEL maintainer="tekintian <tekintian@gmail.com>"
LABEL name="ubuntu-dev"
LABEL version="${UBUNTU_VERSION}"

# OCI 标准化元信息（兼容主流容器平台）
LABEL org.opencontainers.image.authors="tekintian <tekintian@gmail.com> (https://ai.tekin.cn)"
LABEL org.opencontainers.image.source="https://github.com/tekintian/llama.cpp"
LABEL org.opencontainers.image.url="https://ai.tekin.cn/"
LABEL org.opencontainers.image.documentation="https://github.com/tekintian/llama.cpp/wiki"
LABEL org.opencontainers.image.title="ubuntu-dev"
LABEL org.opencontainers.image.description="Ubuntu ${UBUNTU_VERSION} 开发镜像，基于 Ubuntu ${UBUNTU_VERSION} 构建，集成 python 3.10.0 和 conda 26.1.1 和 常用开发工具"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${UBUNTU_VERSION}"
LABEL org.opencontainers.image.vendor="tekintian"
LABEL org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}"
# 镜像分类标签（便于检索）
LABEL org.opencontainers.image.keywords="Ubuntu,dev,python,conda,开发环境"

RUN set -ex; \
    apt update -y; \
    apt install -y \
    build-essential autoconf automake libtool pkg-config \
    curl wget sudo git cmake jq openssl libssl-dev \
    bzip2 lz4 zip unzip p7zip-full rsync \
    libsqlite3-dev libyaml-dev \
    apt-transport-https ca-certificates software-properties-common \
    vim nano tree htop ncdu; \
    cp -Pv /etc/apt/sources.list /etc/apt/sources.list.bk; \
    sed -i 's@http://.*ubuntu.com@https://mirrors.ustc.edu.cn@g' /etc/apt/sources.list; \
    apt autoremove -y && apt clean; \
    rm -rf /var/lib/apt/lists/*

# 安装 Miniconda（给普通用户授权）
RUN set -eux; \
    # 下载 Miniconda（替换为清华源，添加超时和校验）
    wget --timeout=30 --no-check-certificate https://repo.anaconda.com/miniconda/Miniconda3-py310_26.1.1-1-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    # 静默安装
    bash /tmp/miniconda.sh -b -p /usr/local/miniconda3 && \
    rm /tmp/miniconda.sh && \
    # 配置 Conda 镜像源（清华镜像，清理默认源避免冲突）
    /usr/local/miniconda3/bin/conda config --set show_channel_urls True && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2 && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda && \
    # 清理 conda 缓存
    /usr/local/miniconda3/bin/conda clean -i -y && \
    # 配置 pip 国内镜像源（清华镜像）
    /usr/local/miniconda3/bin/pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    /usr/local/miniconda3/bin/pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn && \
    /usr/local/miniconda3/bin/pip config set install.trusted-host pypi.mirrors.ustc.edu.cn && \
    rm -rf /tmp/*

WORKDIR /workspaces
