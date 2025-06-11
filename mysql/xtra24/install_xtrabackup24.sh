#!/bin/bash

# 下载 Percona Release 包
wget -P /tmp https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb

# 安装 Percona Release 包
dpkg -i /tmp/percona-release_latest.$(lsb_release -sc)_all.deb

# 更新包列表
apt update

# 安装依赖包
apt install -y libdbd-mysql-perl libdigest-md5-perl libev-dev socat

# 安装 Percona XtraBackup 24
percona-release enable-only tools release
apt install -y percona-xtrabackup-24

# 安装 Percona Toolkit
apt install -y percona-toolkit

# 安装 qpress
apt install -y qpress

# 清理
rm -f /tmp/percona-release_latest.$(lsb_release -sc)_all.deb

echo "安装完成！"
