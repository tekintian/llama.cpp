#!/usr/bin/env bash

# 默认server构建 Server 版本（默认）
docker build -f alpine.Dockerfile -t tekintian/alpine-llama-cpp:server .

# 构建 CLI 镜像
docker build -f alpine.Dockerfile.cli -t tekintian/alpine-llama-cpp:cli .

docker push tekintian/alpine-llama-cpp:server
docker push tekintian/alpine-llama-cpp:cli

docker tag tekintian/alpine-llama-cpp:server ghcr.io/tekintian/llama-cpp-server:v1.5.9-alpine
docker push ghcr.io/tekintian/llama-cpp-server:v1.5.9-alpine

docker tag tekintian/alpine-llama-cpp:cli ghcr.io/tekintian/llama-cpp-cli:v1.5.9-alpine
docker push ghcr.io/tekintian/llama-cpp-cli:v1.5.9-alpine

docker tag tekintian/alpine-llama-cpp:server registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_server
docker push registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_server

docker tag tekintian/alpine-llama-cpp:cli registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_cli
docker push registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_cli

docker rmi registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_server
docker rmi registry.cn-hangzhou.aliyuncs.com/tekintian/ai:alpine-llama-cpp_cli



