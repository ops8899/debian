#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在安装 Docker..."
    apt update
    apt install -y docker.io
else
    echo "Docker 已安装，跳过安装步骤"
fi

# 检查 Docker Compose 是否已安装
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose 未安装，正在安装 Docker Compose Plugin..."
    apt update
    # 使用清华大学镜像源
    curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-compose-plugin
else
    echo "Docker Compose 已安装，跳过安装步骤"
fi

# 启动 Docker 并设置开机自启
echo "配置 Docker 服务..."
systemctl enable docker
systemctl start docker
echo "Docker 服务已启动并设置为开机自启"

echo ""
echo ""
echo ""
# 创建 Docker 网络
docker network create -d bridge --gateway "172.18.0.1" --subnet "172.18.0.0/16" "local"

# 验证 Docker 和 Compose 版本
docker version
docker compose version

echo "======================="
echo "  安装 Docker 完成"
echo "  Docker 网络 [ local => 172.18.0.0/16 ]"
echo "  使用的网关地址: 172.18.0.1"
echo "======================="
