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
# 环境文件路径
ENV_FILE="/etc/.env"
[ -f "$ENV_FILE" ] || touch "$ENV_FILE"

# 写入文件（若变量不存在）
grep -q "^default_gateway=" "$ENV_FILE" || echo "default_gateway=$default_gateway" >> "$ENV_FILE"
grep -q "^eth0_ip=" "$ENV_FILE" || echo "eth0_ip=$eth0_ip" >> "$ENV_FILE"
grep -q "^c_segment=" "$ENV_FILE" || echo "c_segment=$c_segment" >> "$ENV_FILE"

echo "自定义环境变量:/etc/.env"
cat "$ENV_FILE"

# 导入环境变量
source /etc/.env

echo "当前环境变量"
printenv

# 路由配置
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

sysctl -p

# 允许内网网段的双向通信
iptables -A FORWARD -s $c_segment.0/24 -j ACCEPT
iptables -A FORWARD -d $c_segment.0/24 -j ACCEPT


# 添加 vpnbypass 路由表
ip route add default via $default_gateway dev eth0 table vpnbypass
ip rule add fwmark 1 table vpnbypass


# 需要添加路由的 IP 和网段列表
# 定义 IP 地址列表
ip_list=(
  "1.1.1.1"
  "8.8.8.8"
  "9.9.9.9"
  "114.114.114.114"
  "223.5.5.5"
)

# 循环处理每个 IP 地址
for ip in "${ip_list[@]}"; do
  ip route add "$ip" via "$default_gateway"
  echo "添加路由: $ip via $default_gateway"
done

# 添加 DNS 服务器
echo "nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 114.114.114.114
nameserver 223.5.5.5
" > /etc/resolv.conf
echo "添加 DNS 服务器"
cat /etc/resolv.conf