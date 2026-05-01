#!/bin/bash
set -e  # 遇到错误立即退出

# 1. 更新系统源并升级已安装包
echo "===== 更新系统源并升级已安装包 ====="
sudo apt update && sudo apt upgrade -y

# 2. 安装核心基础开发包（新增cmake）
echo -e "\n===== 安装核心基础开发包 ====="
sudo apt install -y \
  build-essential autoconf automake libtool pkg-config \
  cmake cmake-data \
  curl wget git jq openssl libssl-dev \
  bzip2 lz4 zip unzip p7zip-full rsync \
  libsqlite3-dev libyaml-dev \
  apt-transport-https ca-certificates software-properties-common \
  vim nano tree htop ncdu

# 3. 安装多语言基础运行时
echo -e "\n===== 安装多语言基础运行时 ====="
sudo apt install -y \
  python3 python3-pip python3-venv python3-dev \
  nodejs npm \
  openjdk-17-jdk maven

# # 4. 安装容器工具
# echo -e "\n===== 安装Docker容器工具 ====="
# sudo apt install -y docker.io docker-compose-v2
# sudo usermod -aG docker $USER
# echo "请注销并重新登录，使docker组权限生效"

# 5. 清理缓存
echo -e "\n===== 清理系统缓存 ====="
sudo apt autoremove -y && sudo apt clean

echo -e "\n===== 本地开发环境基础包安装完成 ====="