#!/bin/bash
echo "OpenVPN 拨号断线后执行的脚本：client_disconnect.sh"
echo "参数列表: $*"

# 停止现有的 3proxy 进程
pids=$(pgrep -f "/usr/local/bin/3proxy /root/3proxy/3proxy.cfg")
if [ -n "$pids" ]; then
  echo "正在停止以下 3proxy 进程: $pids"
  kill -9 $pids
fi