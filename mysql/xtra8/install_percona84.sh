#!/bin/bash

# 下载 Percona Release 包到 /tmp 目录
wget -P /tmp https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb

# 安装 Percona Release 包
dpkg -i /tmp/percona-release_latest.$(lsb_release -sc)_all.deb

rm -f /tmp/percona-release_latest.$(lsb_release -sc)_all.deb

# 更新包列表以包含 Percona 存储库
apt update

#percona-release setup ps-80
percona-release enable-only tools release

# 安装 Percona XtraBackup 和其他工具
apt install -y percona-xtrabackup-84 percona-toolkit lz4 zstd

echo "安装完成！"
