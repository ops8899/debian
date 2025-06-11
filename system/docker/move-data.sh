#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 默认路径
DEFAULT_DOCKER_PATH="/data/docker"

# 获取当前完整时间戳
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本必须以root权限运行${NC}"
   exit 1
fi

# 提示用户输入新的Docker数据路径
read -p "请输入新的Docker数据路径 (默认: $DEFAULT_DOCKER_PATH): " DOCKER_PATH
DOCKER_PATH=${DOCKER_PATH:-$DEFAULT_DOCKER_PATH}

# 检查目标目录是否已存在
if [ -d "$DOCKER_PATH" ] && [ "$(ls -A "$DOCKER_PATH")" ]; then
    echo -e "${YELLOW}警告：目标目录 $DOCKER_PATH 已存在且不为空${NC}"
    read -p "是否重命名原目录并继续？(y/n): " force_confirm

    if [[ $force_confirm != [yY] && $force_confirm != [yY][eE][sS] ]]; then
        echo "操作已取消"
        exit 1
    fi

    # 重命名原目录
    BACKUP_PATH="${DOCKER_PATH}_backup_${TIMESTAMP}"
    mv "$DOCKER_PATH" "$BACKUP_PATH"
    echo -e "${GREEN}原目录已重命名为：$BACKUP_PATH${NC}"
fi

# 确认路径
echo -e "${GREEN}将使用路径: $DOCKER_PATH${NC}"
read -p "是否确认? (y/n): " confirm

if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "操作已取消"
    exit 1
fi

# 停止Docker服务
systemctl stop docker

# 创建目标目录
mkdir -p "$DOCKER_PATH"

# 移动整个 docker 目录
mv /var/lib/docker "$DOCKER_PATH"

# 创建软链接
ln -s "$DOCKER_PATH" /var/lib/docker

# 设置权限（使用root）
chown -R root:root "$DOCKER_PATH"

# 重启Docker服务
systemctl start docker

# 验证配置
docker info

echo -e "${GREEN}Docker数据目录迁移完成！${NC}"
