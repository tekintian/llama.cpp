#!/bin/bash
set -euo pipefail

# ===================== 路径变量单独一行定义（规范写法）=====================
# 工作目录
WORK_DIR="/app"
# llama.cpp 源码目录
LLAMA_CPP_DIR="${WORK_DIR}/llama.cpp"
# 编译脚本路径
COMPILE_SCRIPT="/scripts/build_llama_cpp.sh"

# ===================== 友好提示 =====================
echo "========================================"
echo "📦 llama.cpp 开发容器启动中（Rocky Linux 8）"
echo "🔧 编译控制变量 CONTROL_COMPILE: ${CONTROL_COMPILE:-false}"
echo "💡 开发容器默认行为：仅预装依赖，不编译 llama.cpp"
echo "💡 如需编译，请启动容器时添加：-e CONTROL_COMPILE=1"
echo "========================================"

# ===================== 编译逻辑 =====================
if [[ "${CONTROL_COMPILE:-false}" =~ ^(yes|true|1|on)$ ]]; then
    echo -e "\n📌 开始执行 llama.cpp 编译脚本..."
    ${COMPILE_SCRIPT}
    echo -e "\n✅ 编译脚本执行完成！"
else
    echo -e "\nℹ️  跳过编译流程（开发容器默认行为）"
    echo -e "ℹ️  你可以手动执行编译：${COMPILE_SCRIPT}"
fi

# ===================== 进入终端 =====================
echo -e "\n🚀 进入开发容器终端..."
exec "$@"