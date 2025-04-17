#!/bin/bash

# 停止Docker服务
systemctl stop docker

# 更新Docker配置文件
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

# 重启Docker服务
systemctl restart docker

# 验证配置
docker info

echo -e "${GREEN}Docker镜像修改完成！${NC}"
