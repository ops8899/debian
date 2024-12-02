#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 默认值设置
CN_MODE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -cn|--china)
            CN_MODE=true
            shift
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [-cn|--china]"
            exit 1
            ;;
    esac
done

# 判断 CN_MODE 是否为 true
if $CN_MODE; then
    echo "CN_MODE 为 true，切换到国内软件源..."
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    cat >/etc/apt/sources.list<<EOF
# 中科大镜像站
deb http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
    echo "国内源已配置："
    cat /etc/apt/sources.list
else
    echo "CN_MODE 为 false，切换到国际软件源..."
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    cat >/etc/apt/sources.list<<EOF
# 官方 Debian 软件源
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
    echo "国际源已配置："
    cat /etc/apt/sources.list
fi

apt-get update
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
