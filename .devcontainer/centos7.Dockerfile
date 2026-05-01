ARG CENTOS_VERSION=7

FROM centos:$CENTOS_VERSION AS build

ARG TARGETARCH

USER root

# sed -i 's|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.ustc.edu.cn/centos|g' /etc/yum.repos.d/CentOS-*.repo
# 配置 CentOS 7 国内镜像源（阿里云）
RUN sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirrors.aliyun.com|g' /etc/yum.repos.d/CentOS-*.repo && \
    yum update -y && \
    yum clean all && \
    yum makecache && \
    yum install -y wget curl && \
    curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo && \
    yum update -y && \
    yum install -y centos-release-scl && \
    yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-gcc-gfortran && \
    yum install -y \
    openblas-devel \
    gcc \
    gcc-c++ \
    make \
    automake \
    autoconf \
    libtool \
    patch \
    bzip2 \
    gzip \
    tar \
    xz \
    unzip \
    git \
    cmake3 \
    wget \
    openssl-devel && \
    yum clean all && \
    ln -sf /usr/bin/cmake3 /usr/local/bin/cmake

WORKDIR /app

# 安装 Miniconda（给普通用户授权）
RUN set -eux; \
    # 下载 Miniconda（添加超时和校验，避免下载失败）
    wget --timeout=30 --no-check-certificate https://repo.anaconda.com/miniconda/Miniconda3-py310_24.7.1-0-Linux-x86_64.sh -O /tmp/miniconda.sh && \
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
    /usr/local/miniconda3/bin/pip config set install.trusted-host pypi.tuna.tsinghua.edu.cn


WORKDIR /app

# 配置环境变量（确保 conda 可用）
ENV PATH="/usr/local/miniconda3/bin:$PATH"

# 验证安装（使用完整路径，不依赖环境变量）
RUN /usr/local/miniconda3/bin/conda --version && \
    /usr/local/miniconda3/bin/python --version && \
    /usr/local/miniconda3/bin/pip --version
