#!/bin/bash

# 检查是否是 PID 1 进程
if [ "$$" -ne 1 ]; then
  echo "This script must be run as PID 1 (inside the container)."
  exit 1
fi

ip route
netstat -ntlpu

# 启动 systemd
echo "Starting systemd..."
exec /lib/systemd/systemd