#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 默认值
CN_MODE=false
SSH_PORT=22
PASSWORD="Db8899"

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -cn) CN_MODE=true; shift ;;                     # 启用中国模式
        -ssh-port) SSH_PORT="$2"; shift 2 ;;            # SSH 端口
        -pass) PASSWORD="$2"; shift 2 ;;                # 密码
        *) echo "未知选项: $1"; exit 1 ;;                 # 未知参数处理
    esac
done

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[信息]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[警告]${NC} $*"; }
log_error() { echo -e "${RED}[错误]${NC} $*"; }


# 获取所有网络信息
get_all_network_info() {
    echo "当前系统网络配置信息："
    echo "----------------------------------------"

    # 遍历所有有效网卡
    for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -Ev '^(lo|docker|veth|br-|tun|virbr)'); do
        IP_INFO=$(ip addr show $iface | grep 'inet ' | head -n1)
        IP_ADDR=$(echo "$IP_INFO" | awk '{print $2}' | cut -d/ -f1)
        CIDR=$(echo "$IP_INFO" | awk '{print $2}' | cut -d/ -f2)
        GATEWAY=$(ip route show dev $iface | grep default | awk '{print $3}')

        # 计算子网掩码
        if [[ -n "$CIDR" ]]; then
            NETMASK=$(printf "%d.%d.%d.%d\n" \
                $(( (0xFFFFFFFF << (32 - CIDR)) >> 24 & 0xFF )) \
                $(( (0xFFFFFFFF << (32 - CIDR)) >> 16 & 0xFF )) \
                $(( (0xFFFFFFFF << (32 - CIDR)) >> 8 & 0xFF )) \
                $(( (0xFFFFFFFF << (32 - CIDR)) & 0xFF )))
        else
            NETMASK="未分配"
        fi

        echo "网卡: $iface"
        echo "  IP地址: ${IP_ADDR:-未分配}"
        echo "  子网掩码: ${NETMASK:-未分配}"
        echo "  网关: ${GATEWAY:-未配置}"
        echo "----------------------------------------"
    done

    echo
    echo "当前 /etc/network/interfaces 文件内容："
    echo "----------------------------------------"
    cat /etc/network/interfaces
    echo "----------------------------------------"
    ip a
    ip route
    ip rule show
    echo
    echo
    echo "# 重启网络服务命令："
    echo "systemctl restart networking"
    echo
    echo
}

# 获取网络信息
get_network_info() {
    DEFAULT_IFACE=$(ip route | grep '^default' | awk '{print $5}')
    if [ -z "$DEFAULT_IFACE" ]; then
        log_error "无法获取默认网络接口"
        exit 1
    fi

    local IP_INFO=$(ip addr show $DEFAULT_IFACE | grep 'inet ' | head -n1)
    if [ -z "$IP_INFO" ]; then
        log_error "无法获取网络信息"
        exit 1
    fi

    IP=$(echo "$IP_INFO" | awk '{print $2}' | cut -d/ -f1)
    CIDR=$(echo "$IP_INFO" | awk '{print $2}' | cut -d/ -f2)
    GATEWAY=$(ip route show dev $DEFAULT_IFACE | grep default | awk '{print $3}')

    # 计算子网掩码
    NETMASK=$(printf "%d.%d.%d.%d\n" \
        $(( (0xFFFFFFFF << (32 - CIDR)) >> 24 & 0xFF )) \
        $(( (0xFFFFFFFF << (32 - CIDR)) >> 16 & 0xFF )) \
        $(( (0xFFFFFFFF << (32 - CIDR)) >> 8 & 0xFF )) \
        $(( (0xFFFFFFFF << (32 - CIDR)) & 0xFF )))

    log_info "网络信息获取成功:"
    log_info "接口: $DEFAULT_IFACE"
    log_info "IP: $IP"
    log_info "掩码: $NETMASK"
    log_info "网关: $GATEWAY"
}

cd /tmp/ && rm -f /tmp/debi.sh
curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
chmod a+rx debi.sh

# 获取网络配置
get_all_network_info
get_network_info

# 输出参数值（调试用）
echo "是否启用中国模式：$CN_MODE"
echo "SSH 端口：$SSH_PORT"
echo "密码：$PASSWORD"

CMD="./debi.sh --grub-timeout 1 --cdn --network-console --ethx --bbr --user root --password $PASSWORD --ssh-port $SSH_PORT "

[ -n "$IP" ] && CMD+=" --ip '${IP}'"
[ -n "$NETMASK" ] && CMD+=" --netmask '${NETMASK}'"
[ -n "$GATEWAY" ] && CMD+=" --gateway '${GATEWAY}'"
# 根据 CN_MODE 调用不同的参数
if [ "$CN_MODE" = true ]; then
  DNS="114.114.114.114 223.5.5.5 1.1.1.1 8.8.8.8"
  CMD="$CMD --ustc "
else
  DNS="1.1.1.1 8.8.8.8 114.114.114.114 223.5.5.5"
fi
CMD="$CMD --dns '$DNS' "
echo "安装命令：$CMD"
read -p "是否使用当前配置，并执行安装命令？(y/n) " USE_CURRENT
if [[ $USE_CURRENT =~ ^[Yy]$ ]]; then
  eval "$CMD"
  echo "安装完成"
  echo "5秒后重启系统"
  ping 127.0.0.1 -c 5 > /dev/null
  reboot
fi