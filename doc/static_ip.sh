#!/bin/bash

INTERFACE="ens18"  # 确保网卡名称正确
IP="10.202.200.60"
NETMASK="255.255.0.0"
GATEWAY="10.202.200.250"
DNS="1.1.1.1 8.8.8.8"

# 删除旧的配置
sudo sed -i "/^auto $INTERFACE/,/^$/d" /etc/network/interfaces  # 删除 auto 行到下一个空行之间的内容

# 将新配置写入 /etc/network/interfaces 文件
echo -e "auto $INTERFACE\n\
iface $INTERFACE inet static\n\
\taddress $IP\n\
\tnetmask $NETMASK\n\
\tgateway $GATEWAY\n\
\tdns-nameservers $DNS" | sudo tee -a /etc/network/interfaces > /dev/null

# 重启网络服务
sudo systemctl restart networking

echo "网络配置已更新，$INTERFACE 已设置为固定 IP 地址 $IP。"
