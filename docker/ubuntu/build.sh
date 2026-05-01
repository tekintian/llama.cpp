#!/usr/bin/env bash
set -uo pipefail  # 移除-e，改为手动处理错误

# ============================ 通用配置区域 ============================
DOCKERHUB_NAMESPACE="tekintian"
DEFAULT_ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com/tekintian/ai"
DEFAULT_GHCR_REGISTRY="ghcr.io/tekintian"
DEFAULT_BASE_IMAGE_NAME="ubuntu"
DEFAULT_VERSION_TAG="22.04"

# ============================ 全局变量 ============================
declare -A BUILD_TARGETS=()   # key: 后缀名(可为空), value: Dockerfile路径
declare -a PUSH_REGISTRIES=()  # 推送的Registry列表
CLEAN_TAGS=()                 # 待清理的临时标签
FAILED_REGISTRIES=()          # 推送失败的Registry

# ============================ 工具函数 ============================
info() {
    echo -e "\033[34m[INFO] $1\033[0m"
}

success() {
    echo -e "\033[32m[SUCCESS] $1\033[0m"
}

warning() {
    echo -e "\033[33m[WARNING] $1\033[0m"
}

error() {
    echo -e "\033[31m[ERROR] $1\033[0m"
}

# 显示帮助信息
show_help() {
    cat << EOF
通用镜像构建与推送脚本 (容错版)
用法: $0 [选项]

核心特性：
  1. 单个Registry推送失败不影响其他Registry
  2. 支持两种Dockerfile格式：
     - 带后缀: -d dev:dev.Dockerfile (镜像标签: ubuntu:22.04-dev)
     - 无后缀: -d dev.Dockerfile     (镜像标签: ubuntu:22.04)
  3. Docker Hub自动添加tekintian命名空间

选项:
  -h, --help              显示帮助信息
  -b, --base-name <name>  设置基础镜像名称 (默认: ${DEFAULT_BASE_IMAGE_NAME})
  -t, --tag <tag>         设置版本标签 (默认: ${DEFAULT_VERSION_TAG})
  -d, --dockerfile <path> 添加构建目标 (支持两种格式):
                          格式1: 后缀名:Dockerfile路径 (如: dev:dev.Dockerfile)
                          格式2: Dockerfile路径       (如: dev.Dockerfile)
  -r, --registry <type>   添加推送的Registry (支持: dockerhub/ghcr/aliyun，可多次使用)
                          默认: 仅推送dockerhub
  --aliyun-registry <url> 自定义阿里云仓库前缀 (默认: ${DEFAULT_ALIYUN_REGISTRY})
  --ghcr-registry <url>   自定义GHCR仓库前缀 (默认: ${DEFAULT_GHCR_REGISTRY})

标签格式说明:
  - 带后缀: 
    Docker Hub: ${DOCKERHUB_NAMESPACE}/<base>:<version>-<suffix> (如: tekintian/ubuntu:22.04-dev)
    GHCR: ${DEFAULT_GHCR_REGISTRY}/<base>:<version>-<suffix>
    阿里云: ${DEFAULT_ALIYUN_REGISTRY}:<base>_<version>-<suffix>
  - 无后缀:
    Docker Hub: ${DOCKERHUB_NAMESPACE}/<base>:<version> (如: tekintian/ubuntu:22.04)
    GHCR: ${DEFAULT_GHCR_REGISTRY}/<base>:<version>
    阿里云: ${DEFAULT_ALIYUN_REGISTRY}:<base>_<version>
EOF
}

# 校验文件存在性
check_file_exists() {
    local file=$1
    if [ ! -f "${file}" ]; then
        error "文件不存在: ${file}"
        exit 1
    fi
}

# 校验镜像是否存在
check_image_exists() {
    local image_tag=$1
    if ! docker inspect "${image_tag}" &>/dev/null; then
        error "镜像不存在: ${image_tag}"
        exit 1
    fi
}

# 构建镜像（支持带/不带后缀）
build_image() {
    local suffix=$1
    local dockerfile=$2
    local image_tag=""
    
    # 生成镜像标签（带/不带后缀）
    if [[ -z "${suffix}" ]]; then
        image_tag="${DOCKERHUB_NAMESPACE}/${BASE_IMAGE_NAME}:${VERSION_TAG}"
    else
        image_tag="${DOCKERHUB_NAMESPACE}/${BASE_IMAGE_NAME}:${VERSION_TAG}-${suffix}"
    fi
    
    info "开始构建镜像: ${image_tag}"
    if docker build -f "${dockerfile}" -t "${image_tag}" .; then
        success "镜像构建完成: ${image_tag}"
        built_tags+=("${image_tag}")
        # 记录后缀，用于后续标签生成
        image_suffix_map["${image_tag}"]="${suffix}"
    else
        error "镜像构建失败: ${image_tag}"
        exit 1
    fi
}

# 推送镜像（容错版）
push_image() {
    local image_tag=$1
    local reg_type=$2
    
    info "开始推送镜像[${reg_type}]: ${image_tag}"
    if docker push "${image_tag}"; then
        success "镜像推送完成[${reg_type}]: ${image_tag}"
        return 0
    else
        warning "镜像推送失败[${reg_type}]: ${image_tag}（继续执行其他推送）"
        FAILED_REGISTRIES+=("${reg_type}:${image_tag}")
        return 1
    fi
}

# 打标签并推送（容错版，适配不同Registry格式）
tag_and_push() {
    local source_tag=$1
    local reg_type=$2
    local reg_url=$3
    local suffix=${image_suffix_map["${source_tag}"]}
    
    # 解析基础名和版本
    local base_name=$(echo "${source_tag}" | cut -d'/' -f2 | cut -d':' -f1)
    local version_part=$(echo "${source_tag}" | cut -d':' -f2)
    
    # 生成目标标签
    local target_tag=""
    case "${reg_type}" in
        ghcr)
            if [[ -z "${suffix}" ]]; then
                target_tag="${reg_url}/${base_name}:${VERSION_TAG}"
            else
                target_tag="${reg_url}/${base_name}:${VERSION_TAG}-${suffix}"
            fi
            ;;
        aliyun)
            local version_aliyun=${VERSION_TAG//:/_}
            if [[ -z "${suffix}" ]]; then
                target_tag="${reg_url}:${base_name}_${version_aliyun}"
            else
                target_tag="${reg_url}:${base_name}_${version_aliyun}-${suffix}"
            fi
            ;;
        *)
            error "不支持的Registry类型: ${reg_type}"
            return 1
            ;;
    esac
    
    info "为镜像打标签: ${source_tag} -> ${target_tag}"
    if ! docker tag "${source_tag}" "${target_tag}"; then
        warning "打标签失败: ${source_tag} -> ${target_tag}"
        FAILED_REGISTRIES+=("${reg_type}:${target_tag}")
        return 1
    fi
    
    # 推送（容错）
    push_image "${target_tag}" "${reg_type}"
    CLEAN_TAGS+=("${target_tag}")
    return 0
}

# ============================ 主流程 ============================
main() {
    # 初始化默认配置
    local BASE_IMAGE_NAME="${DEFAULT_BASE_IMAGE_NAME}"
    local VERSION_TAG="${DEFAULT_VERSION_TAG}"
    local ALIYUN_REGISTRY="${DEFAULT_ALIYUN_REGISTRY}"
    local GHCR_REGISTRY="${DEFAULT_GHCR_REGISTRY}"

    # 默认推送Docker Hub
    PUSH_REGISTRIES+=("dockerhub")
    
    # 构建成功的镜像标签数组 + 后缀映射
    local built_tags=()
    declare -A image_suffix_map=()

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--base-name)
                BASE_IMAGE_NAME="$2"
                shift 2
                ;;
            -t|--tag)
                VERSION_TAG="$2"
                shift 2
                ;;
            -d|--dockerfile)
                # 支持两种格式：suffix:dockerfile 或 dockerfile
                if [[ "$2" == *":"* ]]; then
                    # 带后缀格式: dev:dev.Dockerfile
                    IFS=':' read -r suffix dockerfile <<< "$2"
                    if [[ -z "${suffix}" || -z "${dockerfile}" ]]; then
                        error "Dockerfile参数格式错误！正确格式: 后缀名:文件路径 或 文件路径"
                        exit 1
                    fi
                else
                    # 无后缀格式: dev.Dockerfile
                    suffix=""
                    dockerfile="$2"
                fi
                BUILD_TARGETS["${suffix}"]="${dockerfile}"
                shift 2
                ;;
            -r|--registry)
                # 去重添加Registry
                if [[ ! " ${PUSH_REGISTRIES[@]} " =~ " $2 " ]]; then
                    PUSH_REGISTRIES+=("$2")
                fi
                shift 2
                ;;
            --aliyun-registry)
                ALIYUN_REGISTRY="$2"
                shift 2
                ;;
            --ghcr-registry)
                GHCR_REGISTRY="$2"
                shift 2
                ;;
            *)
                error "未知参数: $1 (使用 -h 查看帮助)"
                exit 1
                ;;
        esac
    done

    # 基础校验
    if [[ ${#BUILD_TARGETS[@]} -eq 0 ]]; then
        error "未指定任何构建目标！请使用 -d 选项添加 (示例: -d dev.Dockerfile 或 -d dev:dev.Dockerfile)"
        exit 1
    fi

    # 打印配置信息
    info "==================== 执行配置 ===================="
    info "Docker Hub命名空间: ${DOCKERHUB_NAMESPACE}"
    info "基础镜像名称: ${BASE_IMAGE_NAME}"
    info "版本标签: ${VERSION_TAG}"
    info "推送Registry: ${PUSH_REGISTRIES[*]}"
    info "构建目标数量: ${#BUILD_TARGETS[@]}"

    # 1. 构建所有目标镜像
    info "==================== 开始构建镜像 ===================="
    for suffix in "${!BUILD_TARGETS[@]}"; do
        local dockerfile="${BUILD_TARGETS[${suffix}]}"
        check_file_exists "${dockerfile}"
        build_image "${suffix}" "${dockerfile}"
    done

    # 校验是否有构建成功的镜像
    if [[ ${#built_tags[@]} -eq 0 ]]; then
        error "没有构建成功的镜像！"
        exit 1
    fi

    # 2. 推送至指定Registry（容错）
    info "==================== 开始推送镜像 ===================="
    for image_tag in "${built_tags[@]}"; do
        check_image_exists "${image_tag}"
        
        # 推送至各Registry（单个失败不影响其他）
        for reg in "${PUSH_REGISTRIES[@]}"; do
            case "${reg}" in
                dockerhub)
                    # 推送Docker Hub（容错）
                    push_image "${image_tag}" "dockerhub"
                    ;;
                ghcr)
                    tag_and_push "${image_tag}" "ghcr" "${GHCR_REGISTRY}"
                    ;;
                aliyun)
                    tag_and_push "${image_tag}" "aliyun" "${ALIYUN_REGISTRY}"
                    ;;
                *)
                    warning "不支持的Registry类型: ${reg}（跳过）"
                    ;;
            esac
        done
    done

    # 3. 清理临时标签
    if [[ ${#CLEAN_TAGS[@]} -gt 0 ]]; then
        info "==================== 清理本地临时标签 ===================="
        for tag in "${CLEAN_TAGS[@]}"; do
            info "清理标签: ${tag}"
            docker rmi "${tag}" || warning "清理标签失败: ${tag}"
        done
    fi

    # 4. 输出最终结果
    info "==================== 执行结果汇总 ===================="
    success "构建完成的镜像:"
    for tag in "${built_tags[@]}"; do
        echo "  ✅ ${tag}"
    done

    if [[ ${#FAILED_REGISTRIES[@]} -gt 0 ]]; then
        warning "推送失败的镜像:"
        for fail in "${FAILED_REGISTRIES[@]}"; do
            echo "  ❌ ${fail}"
        done
        warning "部分Registry推送失败，但已完成所有可执行的推送操作！"
    else
        success "所有镜像推送成功！"
    fi
}

# 执行主流程
main "$@"