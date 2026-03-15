#!/bin/bash
set -eux

# 确保GCC 9生效
source /opt/rh/devtoolset-9/enable || true

# 1. 克隆源码
git clone --recursive --depth 1 https://github.com/tekintian/llama.cpp.git /app/llama.cpp; \
# 2. 激活 devtoolset-9 编译器（先初始化 MANPATH 避免报错）
export MANPATH="${MANPATH:-/usr/share/man}"; \

cd /app/llama.cpp
rm -rf build && mkdir -p build

# 最优编译参数
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
    -DCMAKE_CXX_FLAGS="-Os -ffunction-sections -fdata-sections" \
    -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--gc-sections" \
    -DCMAKE_C_COMPILER=/opt/rh/devtoolset-9/root/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/opt/rh/devtoolset-9/root/usr/bin/g++ 

# 执行编译
cmake --build build -j$(nproc)

# 验证结果
if [ -f "build/bin/llama-server" ]; then
    echo "✅ llama-server编译成功！"
    ldd build/bin/llama-server | grep -E "(openblas|pthread)" || true
else
    echo "❌ llama-server编译失败！"
    exit 1
fi