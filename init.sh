
sed -i '/proxy1.1ke.net/d' /etc/hosts
echo "110.42.103.131 proxy1.1ke.net" >> /etc/hosts

proxy="socks5h://hi:Hi8899@proxy1.1ke.net:21081" && export all_proxy=$proxy http_proxy=$proxy https_proxy=$proxy && echo "Acquire::socks::proxy \"$proxy\";" | tee /etc/apt/apt.conf.d/proxy.conf

MIRROR="mirrors.aliyun.com"
SOURCES="/etc/apt/sources.list"

# 备份并生成新源
cp $SOURCES ${SOURCES}.bak
cat > $SOURCES << EOF
deb http://${MIRROR}/debian/ bookworm main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://${MIRROR}/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://${MIRROR}/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

export DEBIAN_FRONTEND=noninteractive
# 更新系统
apt-get update -q && apt-get dist-upgrade -y

which git >/dev/null 2>&1 || (apt update && apt install git -y)
rm -rf /debian && cd /
git clone https://github.com/ops8899/debian.git /debian
chmod +x -R /debian/
cd /debian/system
bash 1.sh -ssh-port 61789


# 第一步

proxy-docker socks5://hi:Hi8899@proxy1.1ke.net:21081
docker pull ops8899/proxy

