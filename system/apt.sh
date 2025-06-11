#!/bin/bash

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要root权限运行"
    echo "请使用 sudo $0"
    exit 1
fi

# 设置非交互式环境
export DEBIAN_FRONTEND=noninteractive

bash <(curl -sSL https://linuxmirrors.cn/main.sh) \
  --source mirrors.aliyun.com/ \
  --protocol http \
  --use-intranet-source false \
  --backup true \
  --upgrade-software true \
  --clean-cache false \
  --ignore-backup-tips
