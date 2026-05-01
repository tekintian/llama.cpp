
# llama.cpp 源码编译指南

~~~sh
# 编译环境准备
conda create -n llama.cpp python=3.11
# 激活环境
conda activate llama.cpp

# 进入源码目录
cd /Volumes/work/projects/ai/tools/llama.cpp

# 测试
./build/bin/llama-cli -m demo/test.gguf -p "你好，Tekin是谁?"

# 转换hf模型到gguf
python convert_hf_to_gguf.py demo/qwen3.5-0.8B-custom-finetuned --outfile demo/test.gguf

# 转换模型
/opt/miniconda3/envs/llama.cpp/bin/python convert_hf_to_gguf.py demo/qwen3.5-0.8B-custom-finetuned --outfile demo/qwen3.5-0.8B-tekin-finetuned-fixed.gguf --outtype f16

# 模型量化 对于大多数用途，我推荐使用 q4_K 或 q5_K 量化方法：
llama-quantize demo/qwen3.5-0.8B-tekin-finetuned-fixed.gguf demo/qwen3.5-0.8B-tekin-finetuned-q4_K.gguf q4_K

# 用以下命令查看原始文件和量化后文件的大小对比：
ls -lh qwen-finetuned-*.gguf

# 测试
llama-cli -m t5_translate_en_ru_zh_small_1024_q4_K.gguf -p "你好，Tekin是谁?"
~~~

## 旧版本macos编译优化配置

构建静态库和静态链接的可执行文件
启用 CPU 优化（AVX2, FMA, NATIVE）
启用 BLAS 加速
禁用 Metal 后端（避免兼容性问题）
生成可独立使用的构建物
构建静态库和静态链接的可执行文件

~~~sh
# 1. 进入源码目录（注意：不是 bin 目录，是 llama.cpp 根目录）
cd /Volumes/work/projects/ai/tools/llama.cpp

# 清理编译
rm -rf build
# 配置编译选项（禁用Metal，启用AVX2/FMA, 启用 BLAS 加速, 静态构建, 设置最小兼容版本为 12.0）
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_AVX2=ON \
  -DGGML_FMA=ON \
  -DGGML_NATIVE=ON \
  -DGGML_BLAS=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0

cmake --build build --config Release -j 8

# 构建配置说明
# -DGGML_METAL=OFF - 禁用 Metal 后端（这是解决黑屏问题的关键）
# -DGGML_AVX2=ON - 启用 AVX2 指令集优化（Intel Core i7 支持）
# -DGGML_FMA=ON - 启用 FMA 指令集优化（Intel Core i7 支持）
# -DGGML_NATIVE=ON - 为当前系统进行优化
# -DGGML_BLAS=ON - 启用 BLAS 加速（Intel MKL 或 OpenBLAS）
# -DBUILD_SHARED_LIBS=OFF - 构建静态库而不是动态库
# -DCMAKE_BUILD_TYPE=Release - Release 模式构建
# -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 - 设置最小兼容版本为 12.0

# 静态构建的优势：
# 可移植性强 - 构建物可以在相同架构的系统上直接运行，无需依赖动态库
# 部署简单 - 只需复制单个可执行文件即可
# 版本稳定 - 不会因为系统库更新而出现问题
# 静态构建的注意事项：
# 文件体积较大 - 所有库代码都打包在可执行文件中
# 更新困难 - 需要重新编译才能更新依赖库
# 某些功能可能受限 - 某些系统功能可能需要动态链接

~~~



## 旧版本macos编译优化配置

结合你 macOS 12 + Intel 16GB 硬件环境，以及当前已编译的 llama.cpp（0.9.7 版本）使用场景，我先给出核心结论，再拆解评估维度和实操建议：

### 核心结论
**有必要重新编译，但优先级中等**：
- 「必须改」：禁用 Metal（你当前编译产物仍包含 Metal 模块，导致冗余日志+潜在崩溃）；
- 「建议改」：启用 Intel 专属加速（AVX2/FMA），提升 20%-40% 推理速度；
- 「无需改」：当前版本功能完整，若仅运行 Qwen3.5-2B 且能接受现有速度，可暂缓。

### 一、重新编译的核心收益（针对你的 Intel Mac）
| 优化点                | 未优化编译（当前状态）| 重新编译（Intel 适配）| 收益/影响                          |
|-----------------------|---------------------------------------|-----------------------------------|-----------------------------------|
| Metal 模块            | 编译入产物，触发冗余日志/偶发崩溃     | 彻底禁用（LLAMA_METAL=0）| 消除 Metal 相关报错，运行更稳定    |
| Intel CPU 加速        | 默认仅基础指令集，未启用 AVX2/FMA     | 启用 LLAMA_AVX2=1/LLAMA_FMA=1     | 推理速度提升 20%-40%（16GB 内存下更明显） |
| 线程调度              | 通用多线程，未适配 Intel 多核         | 启用 LLAMA_THREAD_LOCAL=1         | 降低内存占用，减少卡顿            |
| 二进制体积            | 包含 Metal/多模态等冗余模块           | 仅保留 CPU 核心功能               | 启动速度略快，内存占用减少 ~5%    |

### 二、重新编译的具体命令（适配你的环境）
基于你的文件路径 `/Users/tekin/tools/llama.cpp/`，执行以下命令即可完成优化编译：
```bash
# 1. 进入源码目录（注意：不是 bin 目录，是 llama.cpp 根目录）
cd /Users/tekin/tools/llama.cpp

# 2. 清空旧编译产物（关键，避免残留 Metal 模块）
make clean

# 3. 适配 Intel Mac 的编译命令（核心优化）
make \
    LLAMA_METAL=0 \          # 彻底禁用 Metal（消除冗余日志/崩溃）
    LLAMA_CPU_ONLY=1 \       # 仅编译 CPU 核心，精简体积
    LLAMA_AVX2=1 \           # 启用 Intel AVX2 指令集（Intel 6代+CPU都支持）
    LLAMA_FMA=1 \            # 启用 FMA 浮点加速（提升数值计算效率）
    LLAMA_THREAD_LOCAL=1 \   # 优化 Intel 多核线程调度
    -j$(sysctl -n hw.ncpu)   # 用满 CPU 核心加速编译（16GB 内存可放心用）

# 4. 编译完成后，新产物会覆盖 bin 目录下的 llama-cli/llama-server
```

### 三、无需重新编译的场景（可暂缓）
如果满足以下条件，可暂时不编译，先用现有版本：
1. 仅运行 Qwen3.5-2B 小模型，当前推理速度（10-15 t/s）已满足需求；
2. 能接受 Metal 冗余日志，且通过 `--n-gpu-layers 0` 已规避崩溃；
3. 近期无大规模使用 llama.cpp（如批量推理、多模型部署）的需求。

### 四、验证编译效果的方法
重新编译后，运行以下命令验证优化是否生效：
```bash
# 1. 检查 Metal 是否禁用（无输出=成功）
/Users/tekin/tools/llama.cpp/bin/llama-cli --help | grep -i metal

# 2. 测试推理速度（对比编译前）
/Users/tekin/tools/llama.cpp/bin/llama-bench \
    -m /Users/tekin/.cache/modelscope/hub/models/unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-UD-Q4_K_XL.gguf \
    --threads 8
```
- 优化后，`llama-bench` 输出的 `tokens/s` 应提升 20% 以上；
- 启动 `llama-cli` 后，不再出现 `ggml_metal_device_init` 相关日志。

### 总结
1. **核心建议**：建议重新编译，重点通过 `LLAMA_METAL=0` 禁用 Metal、`LLAMA_AVX2=1` 启用 Intel 加速，既解决冗余日志问题，又提升推理速度；
2. **编译成本**：仅需 3 条命令，耗时 2-5 分钟（Intel 16GB Mac 编译速度快），几乎无风险；
3. **收益明确**：稳定性（无 Metal 崩溃）+ 性能（20%-40% 速度提升），适配你的 Intel Mac 硬件特性。

如果编译过程中遇到「AVX2 不支持」等报错（极少数 Intel 老CPU），可去掉 `LLAMA_AVX2=1` 和 `LLAMA_FMA=1` 重新编译，仅保留 `LLAMA_METAL=0` 即可。



## llama.cpp 使用指南
llama.cpp 编译后 `bin` 目录包含了核心可执行程序、动态库和测试工具
本文将梳理这些文件的核心用途，以及如何高效使用关键工具：

### 一、核心文件分类解读
#### 1. 动态库（lib*/*.dylib）
这些是 llama.cpp 的底层依赖库，无需直接调用，被可执行程序（如 llama-cli/llama-server）自动加载：
- `libggml-*`：GGML 张量计算库（核心），包含 CPU/Metal/BLAS 加速模块；
- `libllama.*`：llama.cpp 核心模型推理库，封装了模型加载、采样、生成逻辑；
- `libmtmd.*`：多线程/多设备管理库，适配 Mac 多核心调度。

#### 2. 核心可执行程序（重点关注）
| 程序名          | 核心用途                                                                 | 你已用到/需关注 |
|-----------------|--------------------------------------------------------------------------|----------------|
| `llama-cli`     | 交互式命令行对话（基础功能）| ✅ 已使用       |
| `llama-server`  | 启动 HTTP API 服务（支持/completion/chat/completion 接口）| 🚨 重点使用    |
| `llama-quantize`| 量化 GGUF 模型（如将 BF16 转为 Q4_K_M）| 进阶优化       |
| `llama-embedding` | 生成文本嵌入向量（语义检索/相似度计算）| 扩展功能       |
| `llama-tokenize` | 文本分词/解码（调试 Token 数、上下文长度）| 调试排障       |
| `llama-bench`   | 测试模型推理性能（tokens/s、耗时）| 性能优化       |




#### 3. 专用工具（适配特定模型/场景）
| 程序名              | 用途                                  | 适用场景                          |
|---------------------|---------------------------------------|-----------------------------------|
| `llama-llava-cli`   | 运行 LLaVA 多模态模型（图文问答）| 加载带 mmproj 的多模态 GGUF       |
| `llama-qwen2vl-cli` | 运行 Qwen2-VL 多模态模型              | 你的 Qwen3.5-2B 若支持多模态可用  |
| `llama-finetune`    | 微调 GGUF 模型（LoRA 微调）| 自定义模型训练                    |
| `llama-gguf`        | GGUF 文件管理（查看/编辑/合并）| 查看模型元信息（如量化类型）|

#### 4. 测试工具（test-*）
用于 llama.cpp 开发/调试，普通用户无需使用（如测试分词器、语法解析、线程安全等）。

### 二、基于你的文件路径，启动 llama-server API 服务
你的 `llama-server` 路径是 `llama-server`，结合你本地的 Qwen3.5-2B 模型，完整的 API 服务启动命令如下：
```bash
# 屏蔽 Metal 冗余日志（适配你的旧款 Mac）
export LLAMA_LOG_LEVEL=error

# 启动 llama-server API 服务
llama-server \
    -m ./unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-UD-Q4_K_XL.gguf \
    --ctx-size 4096 \
    --threads 8 \
    --temp 0.6 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.00 \
    --n-gpu-layers 0 \
    --host 0.0.0.0 \  # 允许本机/局域网访问
    --port 8080       # API 端口（默认8080，可改）
```
启动成功后，终端会显示：
```
llama-server: listening on 0.0.0.0:8080
llama-server: using chat template: chatml
llama_model_load: loaded model from [你的GGUF路径]
```

### 三、验证 API 服务（curl 测试）
服务启动后，用以下命令测试单轮对话 API：
```bash
curl http://localhost:8080/completion \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Qwen3.5-2B模型的优势是什么？",
    "temperature": 0.6,
    "max_tokens": 200
  }'
```
返回 JSON 结果包含生成的文本、Token 数、耗时等信息，说明 API 服务正常。

### 四、实用工具使用示例（进阶）
#### 1. 查看 GGUF 模型信息（llama-gguf）
```bash
llama-gguf info ./unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-UD-Q4_K_XL.gguf
```
可查看模型量化类型、参数量、上下文窗口默认值等核心信息，方便调试参数。

#### 2. 测试模型推理性能（llama-bench）
```bash
llama-bench \
    -m ./unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-UD-Q4_K_XL.gguf \
    --threads 8
```
输出 tokens/s、延迟等性能数据，帮你优化 `--threads` 参数。



## CentOS 7 CPU 构建配置

### 1. 首先检查和更新系统工具

CentOS 7 默认的 GCC 版本较老（4.8.x），建议先更新开发工具：

```bash
# 安装开发工具
yum groupinstall "Development Tools" -y

# 安装必要的依赖
yum install -y cmake3 git wget curl

# 创建 cmake3 的软链接（CentOS 7 的 cmake 命令是 cmake3）
ln -sf /usr/bin/cmake3 /usr/local/bin/cmake

# 安装 OpenBLAS（用于 BLAS 加速）
yum install -y openblas-devel
```

### 2. 推荐的构建配置

对于 CentOS 7 的 CPU 环境，推荐以下配置：

```bash
cd /path/to/llama.cpp
rm -rf build

# 基础构建配置（保守的 CPU 指令集）
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=ON \
  -DGGML_BLAS_VENDOR=OpenBLAS \
  -DBUILD_SHARED_LIBS=OFF

cmake --build build --config Release -j$(nproc)
```

### 3. 如果需要更好的性能（支持更多 CPU 指令集）

如果你的 CPU 支持更新的指令集，可以使用：

```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=ON \
  -DGGML_BLAS_VENDOR=OpenBLAS \
  -DGGML_AVX=ON \
  -DGGML_AVX2=ON \
  -DGGML_FMA=ON \
  -DBUILD_SHARED_LIBS=OFF

cmake --build build --config Release -j$(nproc)
```

### 4. 检查 CPU 支持的指令集

在构建前，你可以检查 CPU 支持的指令集：

```bash
# 检查 CPU 信息
cat /proc/cpuinfo | grep flags | head -1

# 或者使用 lscpu
lscpu
```

查找以下标志：
- `sse4_2` - 支持 SSE4.2
- `avx` - 支持 AVX
- `avx2` - 支持 AVX2
- `fma` - 支持 FMA

### 5. 静态链接构建（更好的可移植性）

```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=ON \
  -DGGML_BLAS_VENDOR=OpenBLAS \
  -DGGML_AVX=ON \
  -DGGML_AVX2=ON \
  -DGGML_FMA=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_FIND_LIBRARY_SUFFIXES=.a

cmake --build build --config Release -j$(nproc)
```

### 6. 验证构建

```bash
# 检查依赖
ldd build/bin/llama-cli

# 测试版本
./build/bin/llama-cli --version

# 测试帮助
./build/bin/llama-cli --help
```

## 针对 CentOS 7 的特殊考虑

### 1. 编译器版本问题

CentOS 7 默认的 GCC 4.8.x 可能不支持一些现代 C++ 特性。如果编译失败，可以：

```bash
# 安装 devtoolset-7 或更高版本
yum install -y centos-release-scl
yum install -y devtoolset-7-gcc*

# 启用 devtoolset-7
scl enable devtoolset-7 bash

# 然后重新构建
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=ON
cmake --build build --config Release -j$(nproc)
```

### 2. 内存限制

你的系统只有 2GB 内存，构建时可能需要限制并行任务数：

```bash
# 使用单线程构建（避免内存不足）
cmake --build build --config Release -j1

# 或者使用 2 个线程
cmake --build build --config Release -j2
```

### 3. OpenBLAS 配置

如果 OpenBLAS 有问题，可以禁用 BLAS：

```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=OFF \
  -DBUILD_SHARED_LIBS=OFF

cmake --build build --config Release -j$(nproc)
```

## 推荐的完整构建脚本

```bash
#!/bin/bash

# CentOS 7 llama.cpp 构建脚本

# 1. 安装依赖
yum groupinstall "Development Tools" -y
yum install -y cmake3 git wget curl openblas-devel

# 2. 创建 cmake 软链接
ln -sf /usr/bin/cmake3 /usr/local/bin/cmake

# 3. 克隆或更新代码（如果需要）
# git clone https://github.com/ggml-org/llama.cpp.git
# cd llama.cpp

# 4. 清理旧的构建
rm -rf build

# 5. 配置构建
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_METAL=OFF \
  -DGGML_BLAS=ON \
  -DGGML_BLAS_VENDOR=OpenBLAS \
  -DGGML_AVX=ON \
  -DGGML_AVX2=ON \
  -DGGML_FMA=ON \
  -DBUILD_SHARED_LIBS=OFF

# 6. 构建（使用 2 个线程以避免内存不足）
cmake --build build --config Release -j2

# 7. 验证构建
echo "=== 检查依赖 ==="
ldd build/bin/llama-cli

echo "=== 测试版本 ==="
./build/bin/llama-cli --version

echo "=== 构建完成 ==="
```

## 性能优化建议

对于 2 核 2GB 的虚拟机：

1. **使用较小的模型** - 推荐 1B-3B 参数的模型
2. **使用量化模型** - Q4_K_M 或 Q5_K_M 量化
3. **限制上下文长度** - 使用 `--ctx-size` 参数
4. **调整批处理大小** - 使用较小的批处理

示例运行命令：
```bash
./build/bin/llama-cli \
  -m model.gguf \
  --ctx-size 2048 \
  --batch-size 512 \
  --prompt "Hello"
```

