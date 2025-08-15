#!/bin/bash

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以 root 权限运行"
   exit 1
fi

# 停止 Docker 服务
systemctl stop docker
systemctl disable docker

# 卸载 Docker 相关包
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt-get autoremove -y

# 删除 Docker 相关目录
rm -rf /var/lib/docker
rm -rf /etc/docker
rm -rf ~/.docker

# 清理 Docker 仓库
rm -f /etc/apt/sources.list.d/docker.list

echo "Docker 已成功卸载"
