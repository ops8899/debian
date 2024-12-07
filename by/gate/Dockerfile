# 使用 Debian 12 slim 作为基础镜像
FROM debian:12-slim

# 设置环境变量以避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive
# VPN的客户端DHCP
ENV vpn_dhcp=192.168.30

RUN apt-get update && \
    apt-get -y purge bind9-* && \
    apt-get install -y --no-install-recommends \
        iptables iproute2 net-tools iotop isc-dhcp-client iputils-ping iftop bc tcpdump \
        openvpn curl dnsutils dnsmasq procps vim psmisc traceroute telnet apt-transport-https build-essential

RUN curl -k -L -o  /tmp/vpn_server.tar.gz https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz && \
    tar -xzf /tmp/vpn_server.tar.gz -C /tmp && rm -f /tmp/vpn_server.tar.gz && \
    cd /tmp/vpnserver && \
    yes | make && \
    mv /tmp/vpnserver /usr/local/ && \
    chmod 600 /usr/local/vpnserver/* && \
    chmod 700 /usr/local/vpnserver/vpncmd && \
    chmod 700 /usr/local/vpnserver/vpnserver && \
    ln -s /usr/local/vpnserver/vpnserver /usr/local/bin/vpnserver && \
    ln -s /usr/local/vpnserver/vpncmd /usr/local/bin/vpncmd && \
    ln -s /usr/local/vpnserver/vpn* /root/

# 克隆并安装 3proxy
RUN cd /tmp && \
    curl -k -L -o  3proxy-0.8.13.tar.gz https://github.com/3proxy/3proxy/archive/refs/tags/0.8.13.tar.gz && \
    tar -zxvf 3proxy-0.8.13.tar.gz && \
    cd 3proxy-0.8.13/ && \
    make -f Makefile.Linux && \
    make -f Makefile.Linux install && \
    rm -fr /tmp/3proxy-0.8.13 && \
    ln -s /usr/local/bin/3proxy /root/3proxy


# 清理安装包，减少镜像大小
RUN apt-get purge -y build-essential && apt-get autoremove -y && apt-get clean \
     && rm -rf /var/lib/apt/lists/* /var/log/apt/* /var/log/dpkg.log

# 复制脚本并更新包管理器，安装所需的包，设置配置，清理不必要的文件
COPY copyables/ /root/

RUN chmod +x -R /root/ && \
    mv /root/system/net-check.sh /usr/bin/net-check && \
    mv /root/softether/vpn_server.config /usr/local/vpnserver/ && \
    echo "100 vpnbypass" >> /etc/iproute2/rt_tables && \
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf && \
    echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf && \
    echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf && \
    rm -rf /etc/localtime && ln -s /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime

# 设置工作目录
WORKDIR /root/

# 暴露必要的端口
EXPOSE 443/tcp 992/tcp 1194/tcp 1194/udp 5555/tcp

# 设置3proxy的用户名和密码
ENV proxy_username="hi" proxy_password="Hi8899"

# 设置 OpenVPN 客户端的配置
ENV client_config="" client_username="" client_password="" client_proxy='' client_param=''

# VPN的客户端DHCP
ENV vpn_user1="vpn_user1" vpn_user2="vpn_user2" vpn_dhcp="192.168.30"

# 设置入口点为 entrypoint 脚本
ENTRYPOINT ["/root/entrypoint.sh"]
