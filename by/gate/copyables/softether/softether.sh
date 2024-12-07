#!/bin/bash

# 导入环境变量
source /etc/.env

sed -i "s|VPN_USER1|$vpn_user1|g" /usr/local/vpnserver/vpn_server.config
sed -i "s|VPN_USER2|$vpn_user2|g" /usr/local/vpnserver/vpn_server.config

# 需要标记的端口
PORTS=(
    1080  # SOCKS5 代理端口
    1081  # 备用代理端口
    1194 # VPN 主端口
)
echo "=== 添加端口规则 ==="
for port in "${PORTS[@]}"; do
    echo "处理端口: $port"
    iptables -t mangle -A PREROUTING -s $eth0_ip -p tcp --sport  "$port" -j MARK --set-mark 1
    iptables -t mangle -A OUTPUT -s $eth0_ip -p tcp --sport "$port" -j MARK --set-mark 1
done

# vpn server vlan
iptables -t nat -A POSTROUTING -s $vpn_dhcp.0/24 -o eth0 -j MASQUERADE

# 更换配置
dhcp_config() {
  # 设置 DHCP IP 范围的前缀 (例如 "192.168.30" 或 "10.0.0")
  vpn_dhcp="${vpn_dhcp:-192.168.30}"
  cat <<EOF > /etc/dnsmasq.conf
interface=tap_soft
dhcp-range=tap_soft,${vpn_dhcp}.50,${vpn_dhcp}.150,12h
dhcp-option=tap_soft,3,${vpn_dhcp}.1
dhcp-option=option:dns-server,${vpn_dhcp}.1
resolv-file=/etc/resolv.dnsmasq.conf
strict-order
listen-address=0.0.0.0,::
# 添加或修改以下配置
server=1.0.0.1
server=9.9.9.9
EOF
  # 显示结果
  /etc/init.d/dnsmasq restart
  echo "VPN DHCP 配置: ${vpn_dhcp}"
  /sbin/ifconfig tap_soft ${vpn_dhcp}.1
  /sbin/ifconfig
}

# 启动VPN服务器
/usr/local/vpnserver/vpnserver start

# 切换VPN配置
dhcp_config

log_dir="/usr/local/vpnserver/server_log"

ln -s "$log_dir" /root/log/vpnserver