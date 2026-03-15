# 基础镜像：CentOS 7
FROM centos:7 AS build-env

# 基础维护者信息（兼容传统 LABEL 规范）
LABEL maintainer="tekintian <tekintian@gmail.com>"
LABEL name="centos7-llama.cpp-dev-env"
LABEL version="dev"

# OCI 标准化元信息（兼容 Docker/Containerd/K8s 等主流平台）
LABEL org.opencontainers.image.authors="tekintian <tekintian@gmail.com> (https://ai.tekin.cn)"
LABEL org.opencontainers.image.source="https://github.com/tekintian/llama.cpp"
LABEL org.opencontainers.image.url="https://ai.tekin.cn/"
LABEL org.opencontainers.image.documentation="https://github.com/tekintian/llama.cpp/wiki"
LABEL org.opencontainers.image.title="CentOS7 llama.cpp 开发环境镜像"
LABEL org.opencontainers.image.description="基于 CentOS 7 构建的 llama.cpp 专属开发环境，集成 devtoolset-9 新版编译器、OpenBLAS 数学库加速，默认开启静态编译与体积最小化优化。适配 x86_64 通用架构，原生支持 GGUF 模型推理，内置 HTTP API 服务能力，开箱即用且镜像体积精简，可直接用于 LLM 轻量级推理开发与部署。"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="dev"
LABEL org.opencontainers.image.vendor="tekintian"
LABEL org.opencontainers.image.base.name="docker.io/library/centos:7"
LABEL org.opencontainers.image.architecture="x86_64"
LABEL org.opencontainers.image.ref.name="centos7-llama.cpp-dev-env:dev"

# 镜像分类标签（精准检索，覆盖核心场景）
LABEL org.opencontainers.image.keywords="llama.cpp,CentOS7,OpenBLAS,GGUF,LLM,AI推理,x86_64,devtoolset-9,HTTP API,轻量级推理,静态编译"

# 核心环境变量（初始化所有变量，避免未定义警告）
ENV PATH="/opt/rh/devtoolset-9/root/usr/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"
ENV LD_LIBRARY_PATH="/opt/rh/devtoolset-9/root/usr/lib64:/usr/lib64:/lib64"
ENV MANPATH="/usr/share/man:/opt/rh/devtoolset-9/root/usr/share/man"

COPY ./build_llama_cpp.sh /app/build_llama_cpp.sh

# 第一步：彻底重构源配置（仅保留有效源）
RUN set -ex; \
    # 1. 清空原有失效源
    rm -rf /etc/yum.repos.d/*; \
    # 2. 添加 CentOS 7 Base 官方归档源
    printf "[base]\nname=CentOS-7 - Base\nbaseurl=https://vault.centos.org/centos/7/os/x86_64/\ngpgcheck=0\nenabled=1\n" > /etc/yum.repos.d/CentOS-Base.repo; \
    # 3. 添加 CentOS 7 SCL 归档源（用于 devtoolset-9）
    printf "[centos-sclo-rh]\nname=CentOS-7 - SCLo rh\nbaseurl=https://vault.centos.org/centos/7/sclo/x86_64/rh/\ngpgcheck=0\nenabled=1\n" > /etc/yum.repos.d/CentOS-SCLo.repo; \
    # 4. 添加 CentOS 7 EPEL 有效源（阿里云，可访问 OpenBLAS）
    printf "[epel]\nname=EPEL for CentOS 7\nbaseurl=https://mirrors.aliyun.com/epel/7/x86_64/\ngpgcheck=0\nenabled=1\n" > /etc/yum.repos.d/epel.repo; \
    # 5. 禁用 fastestmirror 插件（避免跳过有效源）
    sed -i 's/^enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf;

# 第二步：安装所有编译依赖（补全缺失工具）
RUN set -ex; \
    yum clean all; \
    yum makecache; \
    # 安装基础工具（补全 make、gcc 基础包）
    yum install -y --nogpgcheck bash wget git cmake3 make gcc gcc-c++; \
    # 安装新版 GCC（devtoolset-9）
    yum install -y --nogpgcheck devtoolset-9-gcc devtoolset-9-gcc-c++; \
    # 安装 OpenBLAS（通过源自动匹配）
    yum install -y --nogpgcheck openblas openblas-devel; \
    # 软链 cmake3 为 cmake
    ln -sf /usr/bin/cmake3 /usr/local/bin/cmake; \
    # 软链 make 确保 CMake 能找到
    ln -sf /usr/bin/make /usr/local/bin/make; \
    # 显示启用devtoolset-9
    chmod +x /app/build_llama_cpp.sh

WORKDIR /app

# 优化 CMD：优先执行传入命令，无传入则启动自动编译
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["if [ $# -eq 0 ]; then /app/build_llama_cpp.sh; else $@; fi", "sh"]
