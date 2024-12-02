#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 默认值
CN_MODE=false
PYTHON=false
SSH_PORT=22
TCP_PORTS=""
UDP_PORTS=""
WHITELIST_IPS=""
DIG_DOMAIN=""
LAN_IPS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -cn|--china-mode) CN_MODE=true; shift ;;                     # 启用中国模式
        -python|--enable-python) PYTHON=true; shift ;;               # 启用 Python
        -ssh-port|--ssh-port) SSH_PORT="$2"; shift 2 ;;              # SSH 端口
        -p|--tcp) TCP_PORTS="$2"; shift 2 ;;                         # UFW TCP 端口
        -u|--udp) UDP_PORTS="$2"; shift 2 ;;                         # UFW UDP 端口
        -w|--white-ips) WHITELIST_IPS="$2"; shift 2 ;;               # UFW 白名单 IP 列表
        -d|--domain) DIG_DOMAIN="$2"; shift 2 ;;                     # UFW DIG 域名
        -l|--lan-ips) LAN_IPS="$2"; shift 2 ;;                       # 内网 IP 范围
        *) echo "未知选项: $1"; exit 1 ;;                            # 未知参数处理
    esac
done

# 输出参数值（调试用）
echo "是否启用中国模式：$CN_MODE"
echo "是否启用 Python 环境安装：$PYTHON"
echo "SSH 端口：$SSH_PORT"
echo "UFW TCP 端口：$TCP_PORTS"
echo "UFW UDP 端口：$UDP_PORTS"
echo "UFW 白名单 IP 列表：$WHITELIST_IPS"
echo "UFW DIG域名：$DIG_DOMAIN"
echo "内网 IP 范围：$LAN_IPS"

# 根据 CN_MODE 调用不同的 apt 脚本
if [ "$CN_MODE" = true ]; then
  bash apt.sh -cn
else
  bash apt.sh
fi

# 系统基础
bash init.sh
bash bin.sh
# 系统参数
bash sysctl.sh
# 开机启动脚本
bash rc.local.sh
# bashrc
bash bashrc.sh
# vim
bash vim.sh
# ssh
bash ssh.sh "$SSH_PORT"
# python
if [ "$PYTHON" = true ]; then
  bash py3.sh
fi
# zsh
bash zsh.sh

# ufw
# 检查参数是否有值
if [[ -n "$TCP_PORTS" || -n "$UDP_PORTS" || -n "$WHITELIST_IPS" || -n "$DIG_DOMAIN" || -n "$LAN_IPS" ]]; then
    echo "执行 ufw_set 命令..."
    ufw_set -p "$TCP_PORTS" -u "$UDP_PORTS" -w "$WHITELIST_IPS" -d "$DIG_DOMAIN" -l "$LAN_IPS"
else
    echo "未提供任何参数，跳过 ufw_set 执行。"
fi

echo "done"