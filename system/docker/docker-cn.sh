#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 选择镜像源
echo -e "${BLUE}请选择 Docker 安装源:${NC}"
echo "1) 国内源 (清华大学镜像)"
echo "2) 官方源 (Docker 官方)"
echo ""
read -p "请输入选择 (1 或 2，默认为 1): " source_choice

# 默认选择国内源
if [ -z "$source_choice" ] || [ "$source_choice" = "1" ]; then
    USE_CHINA_MIRROR=true
    echo -e "${GREEN}已选择: 国内源 (清华大学镜像)${NC}"
elif [ "$source_choice" = "2" ]; then
    USE_CHINA_MIRROR=false
    echo -e "${GREEN}已选择: 官方源 (Docker 官方)${NC}"
else
    echo -e "${YELLOW}无效选择，使用默认的国内源${NC}"
    USE_CHINA_MIRROR=true
fi

echo ""

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker 未安装，正在安装 Docker...${NC}"
    apt update
    apt install -y docker.io
else
    echo -e "${GREEN}Docker 已安装，跳过安装步骤${NC}"
fi

# 检查 Docker Compose 是否已安装
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose 未安装，正在安装 Docker Compose Plugin...${NC}"
    apt update

    if [ "$USE_CHINA_MIRROR" = true ]; then
        echo -e "${BLUE}使用清华大学镜像源安装...${NC}"
        # 使用清华大学镜像源
        curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo -e "${BLUE}使用 Docker 官方源安装...${NC}"
        # 使用官方源
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    apt update
    apt install -y docker-compose-plugin
else
    echo -e "${GREEN}Docker Compose 已安装，跳过安装步骤${NC}"
fi

# 启动 Docker 并设置开机自启
echo -e "${YELLOW}配置 Docker 服务...${NC}"
systemctl enable docker
systemctl start docker
echo -e "${GREEN}Docker 服务已启动并设置为开机自启${NC}"

echo ""
echo ""
echo ""

# 创建 Docker 网络
echo -e "${YELLOW}创建 Docker 网络...${NC}"
if ! docker network ls | grep -q "local"; then
    docker network create -d bridge --gateway "172.30.0.1" --subnet "172.30.0.0/16" "local"
    echo -e "${GREEN}Docker 网络 'local' 创建成功${NC}"
else
    echo -e "${GREEN}Docker 网络 'local' 已存在，跳过创建${NC}"
fi

# 验证 Docker 和 Compose 版本
echo -e "${BLUE}验证安装结果:${NC}"
docker version
docker compose version

echo ""
echo -e "${GREEN}=======================${NC}"
echo -e "${GREEN}  安装 Docker 完成${NC}"
echo -e "${GREEN}  Docker 网络 [ local => 172.30.0.0/16 ]${NC}"
echo -e "${GREEN}  使用的网关地址: 172.30.0.1${NC}"
if [ "$USE_CHINA_MIRROR" = true ]; then
    echo -e "${GREEN}  使用的镜像源: 清华大学镜像${NC}"
else
    echo -e "${GREEN}  使用的镜像源: Docker 官方源${NC}"
fi
echo -e "${GREEN}=======================${NC}"

echo ""
echo -e "${GREEN}所有配置完成！${NC}"
