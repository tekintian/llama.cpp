#!/bin/bash
set -euo pipefail

# ===================== 路径变量单独一行定义（核心规范）=====================
# 工作目录
WORK_DIR="/app"
# llama.cpp 源码目录
LLAMA_CPP_DIR="${WORK_DIR}/llama.cpp"

# ===================== 环境初始化 =====================
export MANPATH="${MANPATH:-/usr/share/man}"

echo -e "\n🔍 系统编译器版本检查："
gcc --version | head -n1
g++ --version | head -n1

# 提前安装filesystem库（保险）
echo -e "\n📦 安装stdc++fs依赖..."
microdnf install -y libstdc++fs-devel || true

# ===================== 清理旧源码 =====================
echo -e "\n🗑️  清理旧的 llama.cpp 目录..."
rm -rf ${LLAMA_CPP_DIR} || true

# ===================== 克隆源码 =====================
echo -e "\n📥 克隆 llama.cpp 源码..."
git clone --recursive --depth 1 https://github.com/tekintian/llama.cpp.git ${LLAMA_CPP_DIR}

# ===================== 编译准备 =====================
cd ${LLAMA_CPP_DIR}
echo -e "\n🧹 清理旧编译产物..."
rm -rf build && mkdir -p build

# ===================== CMake 配置（核心修复）=====================
echo -e "\n⚙️  执行 CMake 配置..."
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_ARCH=x86_64 \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DCMAKE_FORCE_PTHREAD=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_BACKEND_DL=OFF \
    -DCMAKE_LIBRARY_PATH=/usr/lib64 \
    -DCMAKE_INCLUDE_PATH=/usr/include/openblas \
    -DGGML_AVX=ON \
    -DGGML_AVX2=ON \
    -DGGML_FMA=ON \
    -DGGML_SSE3=ON \
    -DGGML_SSE4_1=ON \
    -DGGML_SSE4_2=ON \
    -DGGML_AVX512=OFF \
    -DGGML_AVX_VNNI=OFF \
    -DGGML_AMX=OFF \
    # 修复C++17 filesystem链接问题
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_FLAGS="-Os -ffunction-sections -fdata-sections -lstdc++fs" \
    -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--gc-sections -lstdc++fs"

# ===================== 执行编译 =====================
echo -e "\n🔨 开始编译 llama-server..."
cmake --build build -j$(nproc)

# ===================== 验证结果 =====================
echo -e "\n✅ 编译完成，验证产物..."
if [ -f "build/bin/llama-server" ]; then
    echo -e "✅ llama-server 编译成功！"
    echo -e "\n📋 产物依赖检查："
    ldd build/bin/llama-server | grep -E "(openblas|pthread|libc)" || true
    echo -e "\n📦 产物大小："
    du -h build/bin/llama-server
else
    echo -e "❌ llama-server 编译失败！"
    exit 1
fi

# ===================== 清理临时文件 =====================
rm -rf build/CMakeFiles build/*.cmake || true