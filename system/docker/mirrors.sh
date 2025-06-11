#!/bin/bash

# 定义颜色变量
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 检查是否有remove参数
if [ "$1" = "remove" ]; then
  echo -e "${YELLOW}将移除镜像加速器配置...${NC}"

  # 停止Docker服务
  systemctl stop docker

  # 更新Docker配置文件(不含镜像加速器)
  tee /etc/docker/daemon.json > /dev/null << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-file": "10",
    "max-size": "10m"
  }
}
EOF

else
  echo -e "${YELLOW}将配置默认镜像加速器...${NC}"

  # 停止Docker服务
  systemctl stop docker

  # 更新Docker配置文件(含镜像加速器)
  tee /etc/docker/daemon.json > /dev/null << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-file": "10",
    "max-size": "10m"
  },
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.1panel.live"
  ]
}
EOF

fi

# 重启Docker服务
systemctl restart docker

# 验证配置
docker info

echo -e "${GREEN}Docker配置修改完成！${NC}"
