#!/bin/bash

echo "清空日志目录"
rm -fr /root/log && mkdir -p /root/log

# 启动 Clash
bash ./clash/clash.sh
echo "clash 启动完毕"

# 定时清理日志
nohup bash -c 'while true; do /root/system/clean_log.sh; sleep 86400; done' > /root/log/clean_log.log 2>&1 &

echo "开始监听日志"
tail -f /root/log/*
