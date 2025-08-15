#!/bin/bash

# 自动接受新的配置文件
export DEBIAN_FRONTEND=noninteractive
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade

# 设置变量
MIRROR="mirrors.aliyun.com"
SOURCES="/etc/apt/sources.list"

# 备份原文件
cp $SOURCES ${SOURCES}.bak

# 写入新的源配置
cat > $SOURCES << EOF
deb http://${MIRROR}/debian/ bullseye main contrib non-free
deb http://${MIRROR}/debian/ bullseye-updates main contrib non-free
deb http://${MIRROR}/debian/ bullseye-backports main contrib non-free
deb http://${MIRROR}/debian-security bullseye-security main contrib non-free
EOF


# 1. 更新现有系统
apt update && apt upgrade -y

# 2. 修改源文件从 bullseye 到 bookworm
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list

# 3. 执行升级
apt update
apt full-upgrade -y
apt autoremove -y

# 4. 重启
#reboot
