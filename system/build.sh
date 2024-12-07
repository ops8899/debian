#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  build-essential