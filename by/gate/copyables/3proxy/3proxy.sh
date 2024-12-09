#!/bin/bash
# 启动3POXY
sed -i "s|proxy_username|$proxy_username|g" /root/3proxy/3proxy.cfg
sed -i "s|proxy_password|$proxy_password|g" /root/3proxy/3proxy.cfg
echo "3proxy 配置:"
cat /root/3proxy/3proxy.cfg

pids=$(pgrep -f "/usr/local/bin/3proxy /root/3proxy/3proxy.cfg")
if [ -n "$pids" ]; then
  echo "正在停止以下 3proxy 进程: $pids"
  kill -9 $pids
else
  echo "没有找到正在运行的 3proxy 进程"
fi

/usr/local/bin/3proxy /root/3proxy/3proxy.cfg