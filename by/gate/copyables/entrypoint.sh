#!/bin/bash

# 初始化环境
bash ./system/init.sh

echo "3proxy 配置:"
cat /root/3proxy/3proxy.cfg

# 启动openvpn
if [ -n "$client_config" ]; then
    bash ./openvpn/client.sh &
    echo "openvpn 启动完毕"
else
  # 启动3proxy
  bash ./3proxy/3proxy.sh
  echo "3proxy 启动完毕"
fi

sleep 5

bash ./softether/softether.sh
echo "softether 启动完毕"

# 定时清理日志
nohup bash -c 'while true; do /root/system/clean_log.sh; sleep 86400; done' > /root/log/clean_log.log 2>&1 &

echo "开始监听日志"
tail -f $(find /root/log -type f)
