#!/bin/bash
echo "OpenVPN 拨号成功后执行的脚本：client_up.sh"
echo "参数列表: $*"

# 导入环境变量
source /etc/.env

openvpn_interface=$1

# 更优雅的删除默认路由
echo "正在删除默认路由..."
if ip route show | grep -q "^default"; then
    ip route del default
    echo "已删除默认路由"
else
    echo "没有找到默认路由，跳过删除步骤"
fi

# 添加新的默认路由
echo "添加新的默认路由到 $openvpn_interface..."
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

check_and_add_rule "$vpn_dhcp.0/24" "eth0"
check_and_add_rule "$vpn_dhcp.0/24" "$openvpn_interface"

check_and_add_rule "$c_segment.0/24" "eth0"
check_and_add_rule "$c_segment.0/24" "$openvpn_interface"
