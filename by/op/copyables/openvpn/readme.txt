
#
sysctl -w net.ipv4.ip_forward=1
echo "100 vpnbypass" >> /etc/iproute2/rt_tables


# 配置在 system/init.sh
ip route add default via 10.78.1.1 dev eth0 table vpnbypass
ip rule add fwmark 1 table vpnbypass


# 配置在 openvpn/server.sh
iptables -t mangle -A PREROUTING -p tcp --sport 1443 -j MARK --set-mark 1
iptables -t mangle -A OUTPUT -p tcp --sport 1443 -j MARK --set-mark 1
iptables -t nat -A POSTROUTING -s 10.253.1.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -s 10.253.1.0/24 -j ACCEPT
iptables -A FORWARD -d 10.253.1.0/24 -j ACCEPT



# tun1 从openvpn拨号成功后 client_up.sh 中获取
iptables -t nat -A POSTROUTING -s 10.253.1.0/24 -o tun1 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.78.1.0/24 -o tun1 -j MASQUERADE

