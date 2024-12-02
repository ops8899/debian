FROM riftbit/3proxy:latest as prep_3proxy

FROM alpine:3.12

RUN apk add --no-cache \
    bash jq curl busybox-extras tzdata iptables iproute2 bind-tools bc gawk sed coreutils \
    tcpdump openvpn~=2.4 openssl ca-certificates && \
    update-ca-certificates && \
    ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime && \
    echo "Asia/Hong_Kong" > /etc/timezone && date && \
    echo "100 vpnbypass" >> /etc/iproute2/rt_tables && \
    echo "rt_tables" && cat /etc/iproute2/rt_tables

COPY --from=prep_3proxy /etc/3proxy/3proxy /usr/bin/3proxy
COPY copyables/ /root/

RUN chmod -R +x /root/ /usr/bin/ && \
    mv /root/system/netcheck.sh /usr/bin/netcheck && \
    mv /root/system/proxycheck.sh /usr/bin/proxycheck && \
    chmod 755 /root/ -R && \
    ls -laR /root/

# 设置工作目录
WORKDIR /root

# 设置3proxy的用户名和密码
ENV proxy_username="hi" proxy_password="Hi8899"

# 设置 OpenVPN 服户端的配置
ENV openvpn_server_enable="" openvpn_server_dhcp="10.253.1.0/24" openvpn_server_ca="" openvpn_server_tc="" openvpn_server_param=""

# 设置 OpenVPN 客户端的配置
ENV client_config="" client_username="" client_password="" client_proxy='' client_param=''

# 设置 OpenVPN 客户端的配置证书
ENV client_ca="" client_tc="" client_cert="" client_key=""

# 设置入口点为 entrypoint 脚本
ENTRYPOINT ["/root/entrypoint.sh"]