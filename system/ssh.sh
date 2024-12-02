#!/bin/bash

echo "========================"
echo "  开始优化 SSH 服务"
echo "========================"
# 接收用户输入的端口号，如果未传递，使用默认值 22
SSH_PORT=${1:-22}

# 函数：检查并设置 SSH 配置
set_ssh_config() {
  param=$1
  value=$2
  file="/etc/ssh/sshd_config"

  if grep -q "^#*$param" "$file"; then
    # 参数存在，更新它
    sudo sed -i "s/^#*$param.*/$param $value/" "$file"
    echo "已更新 $param 为 $value"
  else
    # 参数不存在，添加它
    echo "$param $value" | sudo tee -a "$file" >/dev/null
    echo "已添加 $param，值为 $value"
  fi
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本"
  exit 1
fi

echo "开始优化 SSH 服务..."

# 修改 SSH 配置
declare -A ssh_params=(
  ["Port"]="$SSH_PORT"
  ["PasswordAuthentication"]="yes"
  ["PubkeyAuthentication"]="yes"
  ["UseDNS"]="no"
  ["GSSAPIAuthentication"]="no"
  ["LoginGraceTime"]="30"
  ["ClientAliveInterval"]="60"
  ["ClientAliveCountMax"]="3"
  ["X11Forwarding"]="no"
  ["MaxAuthTries"]="3"
  ["Protocol"]="2"
  # ["PermitRootLogin"]="no" # 可根据需要启用
)

# 设置 SSH 参数
for param in "${!ssh_params[@]}"; do
  set_ssh_config "$param" "${ssh_params[$param]}"
done

# 重启 SSH 服务
sudo systemctl restart sshd

netstat -lnptu|grep sshd

echo "新 SSH 端口: $SSH_PORT"
echo "密码和密钥认证均已启用。"
echo "请确保防火墙允许连接到端口 $SSH_PORT。"
echo "建议在关闭此会话前测试新的 SSH 配置。"

echo "========================"
echo "  优化 SSH 服务完成"
echo "========================"
