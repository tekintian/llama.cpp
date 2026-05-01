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

# ========== 创建 vscode 用户（核心） ==========
# 1. 创建 vscode 用户（UID=1000，和 Dev Container 默认一致）
# 2. 配置免密 sudo（开发环境方便操作）
# 3. 创建工作目录并授权
RUN useradd -m -s /bin/bash -u 1000 vscode; \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers; \
    mkdir -p /workspaces; \
    chown -R vscode:vscode /workspaces

# ========== 安装 Miniconda（适配双用户） ==========
RUN set -eux; \
    # 1. 下载 Miniconda（清华源 + 超时）
    wget --timeout=30 --no-check-certificate https://repo.anaconda.com/miniconda/Miniconda3-py310_26.1.1-1-Linux-x86_64.sh -O /tmp/miniconda.sh; \
    # 2. 静默安装（全局目录）
    bash /tmp/miniconda.sh -b -p /usr/local/miniconda3; \
    rm -f /tmp/miniconda.sh; \
    # 3. 提前同意 Conda ToS（容错）
    /usr/local/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main; \
    /usr/local/miniconda3/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r; \
    # tuna tos accept 可选
    /usr/local/miniconda3/bin/conda tos accept --override-channels --channel https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main || true; \
    /usr/local/miniconda3/bin/conda tos accept --override-channels --channel https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r || true; \
    # 4. 配置 Conda 清华镜像源
    /usr/local/miniconda3/bin/conda config --set show_channel_urls True; \
    /usr/local/miniconda3/bin/conda config --remove-key channels || true; \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main; \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r; \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2; \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge; \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/bioconda; \
    # 5. 禁用自动激活 base 环境
    /usr/local/miniconda3/bin/conda config --set auto_activate_base false; \
    # 6. 清理缓存
    /usr/local/miniconda3/bin/conda clean -i -y; \
    # 7. 配置 pip 清华源
    mkdir -p /etc/pip; \
    /usr/local/miniconda3/bin/pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple; \
    /usr/local/miniconda3/bin/pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn; \
    # 8. 配置全局环境变量（root + vscode 用户）
    echo 'export PATH="/usr/local/miniconda3/bin:$PATH"' >> /etc/profile; \
    echo 'export PATH="/usr/local/miniconda3/bin:$PATH"' >> /root/.bashrc; \
    echo 'export PATH="/usr/local/miniconda3/bin:$PATH"' >> /home/vscode/.bashrc; \
    # 9. 给 vscode 用户授权 Miniconda 目录
    chown -R vscode:vscode /usr/local/miniconda3; \
    # 10. 清理临时文件
    rm -rf /tmp/* /var/tmp/*

# ========== 最终配置 ==========
# 设置默认工作目录
WORKDIR /workspaces

# 可选：默认切换到 vscode 用户（也可在 Dev Container 中指定）
# USER vscode

# 配置默认 PATH（确保 Conda 全局可用）
ENV PATH="/usr/local/miniconda3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
