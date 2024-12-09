#!/bin/bash

# 检查必要的软件包
if ! command -v dig &> /dev/null; then
    apt-get update && apt-get install -y dnsutils
fi

if ! command -v openvpn &> /dev/null; then
    apt-get update && apt-get install -y openvpn
fi

# 导入环境变量
source /etc/.env

# 确保必要目录存在
mkdir -p /root/openvpn/config
mkdir -p /root/log

echo "======================"
echo "openvpn config"
echo "config path: $client_config"
echo "user: $client_username password: $client_password"
echo "======================"

# 检查配置文件
if [ -z "$client_config" ]; then
  echo "未指定 OpenVPN 配置文件"
  exit 1
fi

# 获取配置文件路径
client_config="/root/openvpn/config/$client_config"

# 提取 VPN 服务器 IP 或域名
client_remote=$(echo "$client_param" | sed -n 's/.*--remote[[:space:]]\+\([^[:space:]]\+\).*/\1/p')

# 如果未在命令行参数中找到 --remote，从配置文件中获取
if [ -z "$client_remote" ]; then
    if [ -f "$client_config" ]; then
        client_remote=$(grep -E '^[[:space:]]*remote[[:space:]]+[^#]+' "$client_config" | awk '{print $2}' | head -n 1)
        echo "从配置文件中获取 client_remote: $client_remote"
    fi
else
    echo "VPN服务器IP/域名: $client_remote"
fi

# 如果是 IP 地址，直接添加路由；如果是域名，解析 IP 地址
if [[ $client_remote =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ip route add "$client_remote" via "$default_gateway"
  echo "添加路由 $client_remote => $default_gateway"
else
  # 解析域名为 IP 地址
  dns_server="1.0.0.1"
  # 解析 client_remote_ip
  client_remote_ip=$(echo "$client_remote" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || dig @"$dns_server" +short "$client_remote" | head -n 1)
  echo "第1次解析VPN_SERVER_IP: $client_remote_ip"

  # 检查是否成功解析
  if [[ -z "$client_remote_ip" ]]; then
    dns_server="9.9.9.9"
    client_remote_ip=$(echo "$client_remote" | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || dig @"$dns_server" +short "$client_remote" | head -n 1)
    echo "第2次解析VPN_SERVER_IP: $VPN_SERVER_IP"
  fi

  # 检查解析是否成功
  if [[ -n "$client_remote_ip" ]]; then
    # 添加路由
    ip route add "$client_remote_ip" via "$default_gateway"
    echo "添加路由 $client_remote => $default_gateway"
  else
    echo "无法解析域名 $client_remote"
    exit 1
  fi
fi

# 检查并添加参数（两个参数）
add_param_if_missing() {
  local param_name="$1"  # 参数名，例如 "--ping"
  local param_value="$2" # 参数值，例如 "3"

  # 如果参数名不存在，则添加完整的参数
  if [[ ! "$client_param" =~ $param_name ]]; then
    client_param+=" $param_name $param_value"
  fi
}

# 检查并添加参数
# 调用函数，逐个检查并添加
add_param_if_missing "--daemon" "openvpn_client"
add_param_if_missing "--log" "/root/log/openvpn_client.log"
add_param_if_missing "--ping" "10"
add_param_if_missing "--ping-restart" "60"
# 表示第1次失败的1秒后重试一次。
add_param_if_missing "--connect-retry" "1"
#最多重试1次，然后退出程序，才能关闭 3proxy
add_param_if_missing "--connect-retry-max" "1"
#连接服务器/代理服务器的超时时间
add_param_if_missing "--connect-timeout" "10"
# 通过设置为 nointeract，可以让 OpenVPN 在认证失败时自动重试，而不会退出。
#add_param_if_missing "--auth-retry" "nointeract"
# infinite：如果 DNS 解析失败，OpenVPN 会无限重试，直到解析成功。
#add_param_if_missing "--resolv-retry" "infinite"

add_param_if_missing "--route-nopull" #用于防止 OpenVPN 客户端自动接受服务器推送的路由配置。
add_param_if_missing "--route-noexec" #route-noexec 用于防止 OpenVPN 在连接后自动执行路由命令。
add_param_if_missing "--script-security" "2"
add_param_if_missing "--up" "/root/openvpn/client_up.sh"
add_param_if_missing "--down" "/root/openvpn/client_down.sh"

# 如果 client_socks_proxy 和 client_http_proxy 至多只有一个不为空
if [[ -n "$client_socks_proxy" && -n "$client_http_proxy" ]]; then
    echo "错误：client_socks_proxy 和 client_http_proxy 至多只有一个不为空."
    exit 1
fi

# 如果 client_socks_proxy 或 client_http_proxy 不为空
if [[ -n "$client_socks_proxy" ]]; then
    add_param_if_missing "--socks-proxy" "$client_socks_proxy"
fi

if [[ -n "$client_http_proxy" ]]; then
    add_param_if_missing "--http-proxy" "$client_http_proxy"
fi

# if client_proxy is not empty
if [ -n "$client_proxy" ]; then
  bash /root/openvpn/client_proxy_update.sh "$client_config" "$client_proxy"
fi

touch /root/log/openvpn_client.log
chmod 600 /root/log/openvpn_client.log

# 启动 OpenVPN 客户端
echo "OpenVPN 参数: $client_param"
echo "OpenVPN 配置文件: $client_config"
cat $client_config

# 删除默认路由
ip route del default || true  # 添加 || true 防止删除失败时脚本退出

# 无限循环，确保脚本持续运行
while true; do
  # 检查是否有 OpenVPN 进程在运行
  if pgrep openvpn > /dev/null; then
      # 如果 OpenVPN 正在运行，跳过本次循环
      sleep 1
      continue
  fi
  # 尝试先关闭 3proxy 等操作
  bash /root/openvpn/client_down.sh
  echo "正在启动 OpenVPN 客户端..."
  if [ -n "$client_username" ] && [ -n "$client_password" ]; then
    echo "username: $client_username password: $client_password"
    /usr/sbin/openvpn --config "$client_config" --auth-user-pass <(echo -e "$client_username\n$client_password") $client_param &
  else
    /usr/sbin/openvpn --config "$client_config" $client_param &
  fi
done
