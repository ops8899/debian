#!/bin/bash
echo "==============================================================="
echo "开始运行 3proxy"
echo "==============================================================="
# 启动 3proxy
sed -i "s|proxy_username|$proxy_username|g" /root/3proxy/3proxy.cfg
sed -i "s|proxy_password|$proxy_password|g" /root/3proxy/3proxy.cfg
echo "3proxy 配置:"
#cat /root/3proxy/3proxy.cfg
/usr/bin/3proxy /root/3proxy/3proxy.cfg
netstat -ntlpu|grep 3proxy
echo -e "\n3proxy 启动完毕\n"