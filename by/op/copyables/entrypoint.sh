#!/bin/bash

# 初始化环境
bash ./system/init.sh

# 启动 httpd
httpd -p 8081 -h /root/www
echo "启动httpd"

# 启动openvpn
bash ./openvpn/client.sh
echo "openvpn 启动完毕"

# 启动3proxy
bash ./3proxy/3proxy.sh
echo "3proxy 启动完毕"

# 启动openvpn服务器
[[ "$openvpn_server_enable" == "true" ]] && bash ./openvpn/server.sh
echo "openvpn 服务器启动完毕"

# 网络环境检测
( sleep 10 && /usr/bin/netcheck ) &

# 定时清理日志
nohup bash -c 'while true; do /root/system/clean_log.sh; sleep 86400; done' > /root/log/clean_log.log 2>&1 &

echo "开始监听日志"
tail -f /root/log/*
