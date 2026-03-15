#!/bin/bash
set -eux

# 服务器仅需这一个脚本，自动完成依赖安装+库名适配+启动
MODEL_PATH="$1"  # 第一个参数为模型路径
PORT=${2:-8080}  # 第二个参数为端口，默认8080

# 步骤1：安装 OpenBLAS 运行时（仅 openblas-threads.x86_64）
yum install -y openblas-threads.x86_64 || true

# 步骤2：自动适配 CentOS 7 OpenBLAS 库名（核心修复）
OPENBLAS_SO=$(find /usr/lib64 -name "libopenblasp-r*.so" | head -n1)
if [ -n "$OPENBLAS_SO" ] && [ ! -f "/usr/lib64/libopenblas.so.0" ]; then
    ln -sf "$OPENBLAS_SO" /usr/lib64/libopenblas.so.0
    ldconfig
fi

# 步骤3：启动 llama-server（后台运行，输出日志）
nohup ./llama-server \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --ctx-size 2048 \
    --n-threads $(nproc) \
    > llama-server.log 2>&1 &

# 步骤4：验证启动
echo -e "\n✅ llama-server 启动成功！"
echo -e "📄 日志文件：$(pwd)/llama-server.log"
echo -e "🌐 访问地址：http://服务器IP:$PORT/health"
