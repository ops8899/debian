#!/bin/bash

echo "==============================================================="
echo "开始运行 OpenVPN 服务端"
echo "==============================================================="

# 导入环境变量
source /etc/.env

cidr_to_netmask() {
    local cidr=$1
    local ip=${cidr%%/*}
    local prefix=${cidr##*/}

    # 验证 CIDR 格式是否合法
    if [[ ! $cidr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Invalid CIDR format"
        return 1
    fi

    # 根据前缀长度生成子网掩码
    local mask=$(( 0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF ))
    local netmask=$(printf "%d.%d.%d.%d" \
        $(( (mask >> 24) & 0xFF )) \
        $(( (mask >> 16) & 0xFF )) \
        $(( (mask >> 8) & 0xFF )) \
        $(( mask & 0xFF )))

    echo "$ip $netmask"
}

# 需要标记的端口
PORTS=(
    1080  # SOCKS5 代理端口
    1081  # 备用代理端口
    1443 # OpenVPN 主端口
    35555 # OpenVPN 管理端口
)

###################
# 端口规则
###################

echo "=== 添加端口规则 ==="
for port in "${PORTS[@]}"; do
    echo "处理端口: $port"
    iptables -t mangle -A PREROUTING -p tcp --sport "$port" -j MARK --set-mark 1
    iptables -t mangle -A OUTPUT -p tcp --sport "$port" -j MARK --set-mark 1
done

# openvpn server vlan
iptables -t nat -A POSTROUTING -s $openvpn_server_dhcp -o eth0 -j MASQUERADE
iptables -A FORWARD -s $openvpn_server_dhcp -j ACCEPT
iptables -A FORWARD -d $openvpn_server_dhcp -j ACCEPT
# docker network
iptables -A FORWARD -s $c_segment.0/24 -j ACCEPT
iptables -A FORWARD -d $c_segment.0/24 -j ACCEPT

# 配置本地内网路由推送
sed -i "s|route 10.1.1.0 255.255.255.0|route ${c_segment}.0 255.255.255.0|g" /root/openvpn/server/server_tcp.conf

# 启动 OpenVPN 服务端
touch /root/log/openvpn_server_tcp.log
#touch /root/log/openvpn_server_udp.log

openvpn_server_dhcp_netmask=$(cidr_to_netmask $openvpn_server_dhcp)

[[ -n "$openvpn_server_dhcp" ]] && sed -i "s|server 10.253.1.0 255.255.255.0|server $openvpn_server_dhcp_netmask|g" /root/openvpn/server/server_tcp.conf
[[ -z "$openvpn_server_param" ]] && openvpn_server_param=""
# 检查并解码 openvpn_server_ca 变量
[[ -n "$openvpn_server_ca" ]] && echo "$openvpn_server_ca" | base64 -d > /root/openvpn/server/ca.crt
# 检查并解码 openvpn_server_tc 变量
[[ -n "$openvpn_server_tc" ]] && echo "$openvpn_server_tc" | base64 -d > /root/openvpn/server/tc.key
#echo "OpenVPN ca.crt" && cat /root/openvpn/server/ca.crt
#echo "OpenVPN tc.key" && cat /root/openvpn/server/tc.key
#echo "OpenVPN server_tcp.conf" && cat /root/openvpn/server/server_tcp.conf

echo "OpenVPN 服务端 启动参数："
echo "cd /root/openvpn/server/ && /usr/sbin/openvpn --daemon openvpn_server_tcp --management 0.0.0.0 35555 --config server_tcp.conf $openvpn_server_param --config server_tcp.conf $openvpn_server_param"
cd /root/openvpn/server/
echo "OpenVPN 服务端 配置文件："
cat server_tcp.conf
/usr/sbin/openvpn --daemon openvpn_server_tcp --management 0.0.0.0 35555 --config server_tcp.conf $openvpn_server_param

echo -e "\nOpenVPN 服务端 启动完毕\n"