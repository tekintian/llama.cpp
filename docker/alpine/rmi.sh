#!/usr/bin/env bash

# 1. 停止所有运行中的容器（可选，清理停止的容器前可先停止）
docker stop $(docker ps -aq)

# 2. 删除所有已停止的容器
docker rm $(docker ps -aq)

# 3. 删除所有悬空镜像（无标签、无关联容器的镜像）
docker rmi $(docker images -q -f dangling=true)

# 4. 删除所有未被使用的镜像（谨慎！确认不需要的镜像）
docker rmi $(docker images -aq)
