#!/bin/bash

# 用于debian初始化的脚本

# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

echo "======================="
echo "  开始基础工具安装"
echo "======================="


# 更新系统并安装基础工具，使用选项来避免交互
apt-get update
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 安装常用工具和软件，使用选项来避免交互
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  sudo ntpdate openssh-server systemd systemd-sysv cron logrotate \
  net-tools vnstat tcpdump nmap netcat-openbsd isc-dhcp-client iftop wget curl htop vim lsof unzip zip psmisc git ufw rsync \
  traceroute dnsutils  iputils-ping \
  locales sysstat iotop nethogs mtr ncdu pciutils screen expect tree ethtool \
  apt-transport-https ca-certificates software-properties-common \
  python3-pip zsh iproute2 aria2 telnet rclone pv

# 更新证书
update-ca-certificates

# hostname
sed -i "/$(hostname)/d" /etc/hosts && echo "127.0.1.1 $(hostname)" >> /etc/hosts

# ssh
systemctl enable ssh
systemctl start ssh

# 安装 cron
sudo systemctl start cron
sudo systemctl enable cron

# 更新时间
ntpdate -u pool.ntp.org && (crontab -l 2>/dev/null; echo "0 * * * * /usr/sbin/ntpdate -u pool.ntp.org") | crontab -

# 设置 dns
#cat <<EOF | sudo tee /etc/resolv.conf >/dev/null
#nameserver 114.114.114.114
#nameserver 223.5.5.5
#nameserver 1.1.1.1
#nameserver 8.8.8.8
#EOF

# 设置时区为香港
rm -rf /etc/localtime && ln -s /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime

# 设置 locale
echo 'LC_TIME="en_GB.UTF-8"' | sudo tee /etc/default/locale
echo 'LANG="en_US.UTF-8"' | sudo tee -a /etc/default/locale

# 生成 locale
sudo locale-gen en_US.UTF-8 en_GB.UTF-8

# 设置系统 locale
sudo localedef -i en_US -f UTF-8 en_US.UTF-8
sudo localedef -i en_GB -f UTF-8 en_GB.UTF-8

# 检查并添加环境变量到 .profile
{
    if ! grep -q 'export LC_TIME="en_GB.UTF-8"' ~/.profile; then
        echo 'export LC_TIME="en_GB.UTF-8"' >> ~/.profile
    fi

    if ! grep -q 'export LANG="en_US.UTF-8"' ~/.profile; then
        echo 'export LANG="en_US.UTF-8"' >> ~/.profile
    fi

    if ! grep -q 'export LC_ALL="en_US.UTF-8"' ~/.profile; then
        echo 'export LC_ALL="en_US.UTF-8"' >> ~/.profile
    fi
}

# 使 .profile 中的改动立即生效
source ~/.profile

# 输出当前 locale 设置
locale

# 配置日志轮转
cat > /etc/logrotate.conf << 'EOF'
rotate 7
daily
compress
notifempty
delaycompress
EOF

echo "======================="
echo "  基础配置完成"
echo "======================="
