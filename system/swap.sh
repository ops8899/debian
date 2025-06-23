#!/bin/bash

# 获取系统内存大小（GB）
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
DEFAULT_SWAP=$((MEM_GB * 2))

echo "当前系统内存: ${MEM_GB}GB"
echo "推荐swap大小: ${DEFAULT_SWAP}GB (内存的2倍)"
echo

# 提示用户输入
read -p "请输入要创建的swap大小(GB) [默认: ${DEFAULT_SWAP}]: " SWAP_INPUT

# 如果用户没有输入，使用默认值
if [ -z "$SWAP_INPUT" ]; then
    SWAP_GB=$DEFAULT_SWAP
else
    # 验证输入是否为数字
    if [[ "$SWAP_INPUT" =~ ^[0-9]+$ ]] && [ "$SWAP_INPUT" -gt 0 ]; then
        SWAP_GB=$SWAP_INPUT
    else
        echo "错误: 请输入有效的数字"
        exit 1
    fi
fi

echo "将创建 ${SWAP_GB}GB 的swap文件..."

# 检查是否已存在swap文件
if [ -f /swapfile ]; then
    echo "检测到已存在的swap文件"
    read -p "是否要删除重新创建? (y/N): " RECREATE
    if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
        echo "已删除旧的swap文件"
    else
        echo "保持现有swap配置"
        exit 0
    fi
fi

# 创建swap文件
echo "正在创建 ${SWAP_GB}GB swap文件..."
if sudo fallocate -l ${SWAP_GB}G /swapfile; then
    echo "swap文件创建成功"
else
    echo "错误: swap文件创建失败"
    exit 1
fi

# 设置权限
sudo chmod 600 /swapfile

# 格式化为swap
if sudo mkswap /swapfile; then
    echo "swap格式化成功"
else
    echo "错误: swap格式化失败"
    exit 1
fi

# 启用swap
if sudo swapon /swapfile; then
    echo "swap启用成功"
else
    echo "错误: swap启用失败"
    exit 1
fi

# 添加到fstab（如果不存在）
if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    echo "已添加到 /etc/fstab，重启后自动挂载"
else
    echo "/etc/fstab 中已存在swap配置"
fi

echo
echo "✅ Swap设置完成！"
echo "当前内存使用情况："
free -h
