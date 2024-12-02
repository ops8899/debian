#!/bin/bash
# 获取脚本名称
SCRIPT_NAME=$(basename "$0")

# 检查是否已经在运行
if [ "$(ps aux | grep "$SCRIPT_NAME" | grep -v grep | wc -l)" -gt 1 ]; then
    echo "Process is already running"
    exit 1
fi

while true
do
  ping www.google.com -c 1 > /dev/null 2>&1
  sleep 5
done
