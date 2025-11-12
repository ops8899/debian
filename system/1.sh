#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 默认值
CN_MODE=false
PYTHON_ENV=false
SSH_PORT=22
UFW=""

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -python) PYTHON_ENV=true; shift ;;              # 启用 Python
        -ssh-port) SSH_PORT="$2"; shift 2 ;;        # SSH 端口
        -ufw) UFW="$2"; shift 2 ;;              # UFW 规则
        -ufw-domain) UFW_DOMAIN="$2"; shift 2 ;;       # UFW DIG 域名
        *) echo "未知选项: $1"; exit 1 ;;             # 未知参数处理
    esac
done

# 输出参数值（调试用）
echo "是否启用 Python 环境安装：$PYTHON_ENV"
echo "SSH 端口：$SSH_PORT"
echo "UFW 参数：$UFW"
echo "UFW txt域名：$UFW_DOMAIN"
echo "内网 IP 范围：$LAN_IPS"

# apt
bash apt.sh

# 系统基础
bash init.sh

# ssh
bash ssh.sh "$SSH_PORT"

bash bin.sh
# 系统参数
bash sysctl.sh
# 开机启动脚本
bash rc.local.sh
# bashrc
bash bashrc.sh
# vim
bash vim.sh
# python
if [ "$PYTHON_ENV" = true ]; then
  bash py3.sh
fi

# zsh
bash zsh.sh

# ufw
# 检查参数是否有值
if [[ -n "$UFW" || -n "$UFW_DOMAIN" ]]; then
    echo "执行 ufw_set 命令..."
    ufw_set $UFW -txt "$UFW_DOMAIN"
else
    echo "未提供任何参数，跳过 ufw_set 执行。"
fi

echo "done"