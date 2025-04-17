#!/bin/bash

# 默认路径
DEFAULT_DOCKER_PATH="/data/docker"

# 提示用户输入新的Docker数据路径
read -p "请输入新的Docker数据路径 (默认: $DEFAULT_DOCKER_PATH): " DOCKER_PATH
DOCKER_PATH=${DOCKER_PATH:-$DEFAULT_DOCKER_PATH}

# 确认路径
echo "将使用路径: $DOCKER_PATH"
read -p "是否确认? (y/n): " confirm

if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "操作已取消"
    exit 1
fi

# 停止Docker服务
sudo systemctl stop docker

# 创建目标目录
sudo mkdir -p "$DOCKER_PATH"

# 移动默认Docker数据
sudo mv /var/lib/docker/* "$DOCKER_PATH/"

# 更新Docker配置文件
sudo tee /etc/docker/daemon.json > /dev/null << EOF
{
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-file": "10",
    "max-size": "10m"
  },
  "registry-mirrors": [
    "https://mirror.azure.cn",
    "https://docker.1panel.live"
  ],
  "data-root": "$DOCKER_PATH"
}
EOF

# 设置权限（使用root）
sudo chown -R root:root "$DOCKER_PATH"

# 重启Docker服务
sudo systemctl start docker

# 验证配置
docker info
