#!/bin/bash

echo "==============================================================="
echo "开始运行 clash"
echo "==============================================================="

# 导入环境变量
source /etc/.env

if [ -z "$clash_config" ]; then
  echo "未指定 clash 配置,不运行 clash"
  exit 1
fi

download() {
    for i in {1..2}; do
        echo "尝试下载: $1 ($i/2)"
        [ "$(curl -w "%{http_code}" -f --connect-timeout 5 --max-time 5 -sL "$1" -o "$2")" -eq 200 ] && return 0
    done
    return 1
}

# URL 编码函数
encodeURI() {
    local input="$1"
    # 使用 jq 进行 URL 编码
    local encoded=$(jq -nr --arg str "$input" '$str | @uri')
    echo "$encoded"
}

# if /root/clash/config.yaml not exist
if [ ! -f "/root/clash/config.yaml" ]; then
  echo "开始初始化 clash 配置"
  # 生成 proxies 部分
  if [ -n "$clash_proxies" ]; then
    echo "clash_config: $clash_config"
    echo "clash_proxies: $clash_proxies"
    proxies_section="proxies:"
    # 使用逗号分隔的字符串转换为数组
    IFS=',' read -r -a PROXIES_ARRAY <<<"$clash_proxies"
    # 检查每个网关是否为非IP格式
    for i in "${!PROXIES_ARRAY[@]}"; do
      proxies_section="$proxies_section
    - {name: ${PROXIES_ARRAY[$i]}, server: ${PROXIES_ARRAY[$i]}, port: 1081, type: socks5}"
    done
    echo "$proxies_section" > /root/clash/proxies.yaml
    cp /root/clash/$clash_config /root/clash/config.yaml
  elif [ -n "$clash_url" ]; then
    echo "节点URL: $clash_url"
    encoded_clash_url=$(encodeURI "$clash_url")
    #subconvert param
    base_url="sub?target=clash&list=true"
    # 定义临时标记
    TEMP_MARKER="___PIPE___"
    if [ -n "$clash_include" ]; then
      # 处理 include 参数
      clash_include=${clash_include//|/$TEMP_MARKER}
      clash_include=$(encodeURI "$clash_include")
      clash_include=${clash_include//$TEMP_MARKER/|}
      base_url="${base_url}&include=($clash_include)"
    fi
    if [ -n "$clash_exclude" ]; then
      # 处理 exclude 参数
      clash_exclude=${clash_exclude//|/$TEMP_MARKER}
      clash_exclude=$(encodeURI "$clash_exclude")
      clash_exclude=${clash_exclude//$TEMP_MARKER/|}
      base_url="${base_url}&exclude=($clash_exclude)"
    fi
    base_url="${base_url}&url=${encoded_clash_url}"
    url1="https://sub.xeton.dev/$base_url"
    url2="https://api.dler.io/$base_url"
    save_file="/root/clash/proxies.yaml"
    download "$url1" "$save_file" || { echo "主地址失败，切换备用地址..."; download "$url2" "$save_file" || { echo "下载失败，安装中止。"; exit 1; }; }
    cp /root/clash/$clash_config /root/clash/config.yaml
  else
    echo "默认配置启动"
    cp /root/clash/default.yaml /root/clash/config.yaml
  fi
fi

# 修改默认代理用户名密码
sed -i "s|\"proxy_username:proxy_password\"|\"$proxy_username:$proxy_password\"|g" /root/clash/config.yaml
echo "节点配置:"
echo "当前Clash配置:"
cat /root/clash/config.yaml
# if /root/clash/proxies.yaml exists
if [ -f "/root/clash/proxies.yaml" ]; then
  cat /root/clash/proxies.yaml
fi

echo "当前服务器监听端口"
netstat -ntlpu


touch /root/log/clash.log
nohup /usr/bin/mihomo -d /root/clash/ > /root/log/clash.log 2>&1 &

