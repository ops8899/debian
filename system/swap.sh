#!/bin/bash
SWAP_GB=$(($(free -g | awk '/^Mem:/{print $2}') * 2))

# 创建swap文件（如果不存在）
[ ! -f /swapfile ] && sudo fallocate -l ${SWAP_GB}G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile

# 启用swap
swapon /swapfile 2>/dev/null

# 添加到fstab（如果不存在）
grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null

echo "Swap设置完成"
free -h
