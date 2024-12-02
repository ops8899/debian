#!/bin/bash
echo "OpenVPN 拨号成功后执行的脚本：route_set.sh"
echo "参数列表: $*"

# 导入环境变量
source /etc/.env

openvpn_interface=$1
ip route del default
ip route add default dev "$openvpn_interface"

check_and_add_rule() {
    local subnet=$1
    local iface=$2
    if ! iptables -t nat -C POSTROUTING -s $subnet -o $iface -j MASQUERADE 2>/dev/null; then
        echo "添加规则: $subnet => $iface MASQUERADE"
        iptables -t nat -A POSTROUTING -s $subnet -o $iface -j MASQUERADE
    else
        echo "忽略添加规则（已存在）: $subnet => $iface MASQUERADE"
    fi
}

check_and_add_rule "$server_dhcp" "eth0"
check_and_add_rule "$server_dhcp" "$openvpn_interface"

check_and_add_rule "$c_segment.0/24" "eth0"
check_and_add_rule "$c_segment.0/24" "$openvpn_interface"