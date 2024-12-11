#!/bin/bash

echo "==============================================================="
echo "开始初始化环境"
echo "==============================================================="

echo "清空日志目录"
rm -fr /root/log && mkdir -p /root/log

# 获取网关地址
default_gateway=$(ip route | awk '/default/ {print $3}')
eth0_ip=$(ip -4 addr show eth0 | awk '/inet / {print $2}' | cut -d'/' -f1)
c_segment="${default_gateway%.*}"

echo ""
echo "当前网关地址: $default_gateway"
echo "eth0 的 IP: $eth0_ip"
echo "eth0 的 C 段: $c_segment"
echo ""

# 导出变量
ENV_FILE="/etc/.env"
[ -f "$ENV_FILE" ] || touch "$ENV_FILE"

# 写入环境变量
echo "default_gateway=$default_gateway" > "$ENV_FILE"
echo "eth0_ip=$eth0_ip" >> "$ENV_FILE"
echo "c_segment=$c_segment" >> "$ENV_FILE"
echo "vpn_dhcp=$vpn_dhcp" >> "$ENV_FILE"

echo "自定义环境变量:/etc/.env"
cat "$ENV_FILE"

# 导入环境变量
source /etc/.env

echo "当前环境变量"
printenv

# 添加 vpnbypass 路由表
ip route add default via $default_gateway dev eth0 table vpnbypass 2>/dev/null || true
ip rule add fwmark 1 table vpnbypass 2>/dev/null || true

# IP 列表
ip_list=(
  "1.0.0.1"
  "9.9.9.9"
)

# 循环处理每个 IP 地址
for ip in "${ip_list[@]}"; do
  ip route replace "$ip" via "$default_gateway"
  echo "添加路由: $ip via $default_gateway"
done

# 添加 DNS 服务器
echo "nameserver 1.1.1.1
nameserver 8.8.8.8
" > /etc/resolv.conf
echo "添加 DNS 服务器"
cat /etc/resolv.conf

# 允许所有网段的双向通信
iptables -A FORWARD -j ACCEPT

