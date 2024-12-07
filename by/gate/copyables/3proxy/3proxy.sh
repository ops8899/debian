#!/bin/bash
# 启动3POXY
sed -i "s|proxy_username|$proxy_username|g" /root/3proxy/3proxy.cfg
sed -i "s|proxy_password|$proxy_password|g" /root/3proxy/3proxy.cfg
echo "3proxy 配置:"
cat /root/3proxy/3proxy.cfg
/usr/local/bin/3proxy /root/3proxy/3proxy.cfg