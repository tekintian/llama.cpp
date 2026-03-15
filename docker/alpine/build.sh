#!/usr/bin/env bash
# 构建和自动推送 Alpine 版本的 Llama.cpp 镜像
# 说明：
# 1. 构建 Alpine 版本的 Llama.cpp 镜像
# 2. 包含 Server 和 CLI 版本
# 3. 支持 AMD64 和 ARM64 架构
# 4. 镜像大小约 100MB（相比 CentOS 7 版本小 50MB）
# 5. 自动推送至 Docker Hub, GHCR 和阿里云镜像仓库
#
# 构建之前需要先登录 Docker Hub, GHCR 和阿里云镜像仓库
# 登录 GHCR 镜像仓库 令牌生成地址：https://github.com/settings/tokens
# echo "${GITHUB_TOKEN}" | docker login ghcr.io -u tekintian --password-stdin
# 登录 Docker Hub 镜像仓库
# docker login docker.io -u tekintian --password-stdin
# 登录阿里云镜像仓库
# docker login registry.cn-hangzhou.aliyuncs.com -u tekintian --password-stdin
#

set -euo pipefail

# ============================ 配置区域 ============================
# 基础配置（集中管理，方便修改）
BASE_IMAGE_NAME="tekintian/alpine-llama-cpp"
VERSION_TAG="v1.5.9-alpine"
ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com/tekintian/ai"
GHCR_REGISTRY="ghcr.io/tekintian"

# 构建目标配置（结构化管理）
declare -A BUILD_TARGETS=(
    ["server"]="alpine.Dockerfile"
    ["cli"]="alpine.Dockerfile.cli"
)

# ============================ 工具函数 ============================
# 彩色输出函数（提升可读性）
info() {
    echo -e "\033[34m[INFO] $1\033[0m"
}

success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"
}

error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
    exit 1
}

# 构建镜像函数
build_image() {
    local target=$1
    local dockerfile=$2
    local tag="${BASE_IMAGE_NAME}:${target}"

    info "开始构建 ${target} 镜像..."
    if docker build -f "${dockerfile}" -t "${tag}" .; then
        success "${target} 镜像构建完成"
    else
        error "${target} 镜像构建失败"
    fi
}

# 推送镜像函数
push_image() {
    local tag=$1

    info "开始推送镜像: ${tag}..."
    if docker push "${tag}"; then
        success "镜像 ${tag} 推送完成"
    else
        error "镜像 ${tag} 推送失败"
    fi
}

# 打标签并推送函数
tag_and_push() {
    local source_tag=$1
    local target_tag=$2

    info "为镜像打标签: ${source_tag} -> ${target_tag}..."
    docker tag "${source_tag}" "${target_tag}"
    push_image "${target_tag}"
}

# ============================ 主流程 ============================
main() {
    info "开始执行镜像构建和推送流程"

    # 1. 构建所有目标镜像
    for target in "${!BUILD_TARGETS[@]}"; do
        build_image "${target}" "${BUILD_TARGETS[${target}]}"
    done

    # 2. 推送基础镜像
    for target in "${!BUILD_TARGETS[@]}"; do
        push_image "${BASE_IMAGE_NAME}:${target}"
    done

    # 3. 推送 GHCR 镜像
    tag_and_push "${BASE_IMAGE_NAME}:server" "${GHCR_REGISTRY}/llama-cpp-server:${VERSION_TAG}"
    tag_and_push "${BASE_IMAGE_NAME}:cli" "${GHCR_REGISTRY}/llama-cpp-cli:${VERSION_TAG}"

    # 4. 推送阿里云镜像
    tag_and_push "${BASE_IMAGE_NAME}:server" "${ALIYUN_REGISTRY}:alpine-llama-cpp_server"
    tag_and_push "${BASE_IMAGE_NAME}:cli" "${ALIYUN_REGISTRY}:alpine-llama-cpp_cli"

    # 5. 清理阿里云镜像标签
    info "清理本地阿里云镜像标签..."
    docker rmi "${ALIYUN_REGISTRY}:alpine-llama-cpp_server" || true
    docker rmi "${ALIYUN_REGISTRY}:alpine-llama-cpp_cli" || true

    success "所有镜像构建和推送流程执行完成！"
}

# 执行主流程
main
