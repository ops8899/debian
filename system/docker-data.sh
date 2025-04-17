#!/bin/bash

# 默认路径
DEFAULT_DOCKER_PATH="/data/docker"

# 获取当前完整时间戳
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# 提示用户输入新的Docker数据路径
read -p "请输入新的Docker数据路径 (默认: $DEFAULT_DOCKER_PATH): " DOCKER_PATH
DOCKER_PATH=${DOCKER_PATH:-$DEFAULT_DOCKER_PATH}

# 检查目标目录是否已存在
if [ -d "$DOCKER_PATH" ] && [ "$(ls -A "$DOCKER_PATH")" ]; then
    echo "警告：目标目录 $DOCKER_PATH 已存在且不为空"
    read -p "是否重命名原目录并继续？(y/n): " force_confirm

    if [[ $force_confirm != [yY] && $force_confirm != [yY][eE][sS] ]]; then
        echo "操作已取消"
        exit 1
    fi

    # 重命名原目录
    BACKUP_PATH="${DOCKER_PATH}_backup_${TIMESTAMP}"
    mv "$DOCKER_PATH" "$BACKUP_PATH"
    echo "原目录已重命名为：$BACKUP_PATH"
fi

# 确认路径
echo "将使用路径: $DOCKER_PATH"
read -p "是否确认? (y/n): " confirm

if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "操作已取消"
    exit 1
fi

# 停止Docker服务
systemctl stop docker

# 创建目标目录
mkdir -p "$DOCKER_PATH"

# 移动默认Docker数据
mv /var/lib/docker/* "$DOCKER_PATH/"

# 更新Docker配置文件
tee /etc/docker/daemon.json > /dev/null << EOF
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
    "https://docker.1ms.run",
    "https://docker.1panel.live"
  ],
  "data-root": "$DOCKER_PATH"
}
EOF

# 设置权限（使用root）
chown -R root:root "$DOCKER_PATH"

# 重启Docker服务
systemctl restart docker

# 验证配置
docker info

echo "Docker数据目录迁移完成！"
