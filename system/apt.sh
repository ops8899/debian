#!/bin/bash

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要root权限运行"
    echo "请使用 sudo $0"
    exit 1
fi

# 设置非交互式环境
export DEBIAN_FRONTEND=noninteractive

# 定义文件路径
SOURCES_LIST="/etc/apt/sources.list"
SOURCES_DIR="/etc/apt/sources.list.d"

# 解析参数
if [[ "$1" == "-cn" || "$1" == "--china" ]]; then
    MIRROR="mirrors.aliyun.com"
    SECURITY_MIRROR="mirrors.aliyun.com"
else
    MIRROR="deb.debian.org"
    SECURITY_MIRROR="security.debian.org"
fi

# 备份原有配置
echo "备份现有配置..."
timestamp=$(date +%Y%m%d_%H%M%S)
[ -f "$SOURCES_LIST" ] && cp "$SOURCES_LIST" "${SOURCES_LIST}.bak.${timestamp}"

# 禁用 sources 格式文件（如果存在）
if [ -f "/etc/apt/sources.list.d/debian.sources" ]; then
    echo "发现 debian.sources 文件，正在禁用..."
    mv "/etc/apt/sources.list.d/debian.sources" "/etc/apt/sources.list.d/debian.sources.disabled"
fi

# 生成新的 sources.list
echo "生成新的软件源配置..."
cat > "$SOURCES_LIST" << EOF
deb http://${MIRROR}/debian/ bookworm main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://${SECURITY_MIRROR}/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

# 更新系统
echo "正在更新软件包列表..."
apt-get update -q

echo "正在更新系统..."
apt-get dist-upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

echo "更新完成！"
