#!/bin/bash

echo "==============================================================="
echo "开始运行 clash"
echo "==============================================================="

# 定义常量
CLASH_DIR="/root/clash"
CLASH_CONFIG="$CLASH_DIR/config.yaml"
LOG_FILE="/root/log/clash.log"

# URL 编码函数
encodeURI() {
    local input="$1"
    local encoded=$(jq -nr --arg str "$input" '$str | @uri')
    echo "$encoded"
}

# 下载函数
download() {
    for i in {1..2}; do
        echo "尝试下载: $1 ($i/2)"
        [ "$(curl -w "%{http_code}" -f --connect-timeout 5 --max-time 5 -vL "$1" -o "$2")" -eq 200 ] && return 0
    done
    return 1
}

# 函数：下载配置文件
download_with_fallback() {
    local url="$1"
    local save_file="$2"

    for server in "$subconvert1" "$subconvert2" "$subconvert3"; do
        echo "尝试从 $server 下载..."
        if download "$server/$url" "$save_file"; then
            return 0
        fi
        echo "从 $server 下载失败，尝试下一个服务器..."
    done

    echo "所有下载源均失败，安装中止。"
    exit 1
}

# 函数：下载特定区域的配置
download_region_config() {
    local region="$1"
    local include_pattern="$2"
    local exclude_pattern="$3"
    local output_file="$CLASH_DIR/proxies_${region}.yaml"

    local url="${base_url}&url=${encoded_clash_url}&include=$(encodeURI "$include_pattern")&exclude=$(encodeURI "$exclude_pattern")"
    download_with_fallback "$url" "$output_file"
}

# 停止现有的 clash 进程
echo "检查并停止现有 clash 进程"
kill -9 $(ps aux | grep '[m]ihomo' | awk '{print $2}') 2>/dev/null || true

# 初始化配置
if [ ! -f "$CLASH_CONFIG" ]; then
    echo "初始化 clash 配置"

    if [ -n "$clash_url" ]; then
        # 配置订阅地址
        echo "配置订阅地址"
        subconvert1="http://172.17.0.1:25500"
        subconvert2="https://sub.xeton.dev"
        subconvert3="https://api.dler.io"

        encoded_clash_url=$(encodeURI "$clash_url")
        base_url="sub?target=clash&list=true"

        # 下载各个区域的配置
        download_region_config "default" "${clash_include:-}" "${clash_exclude:-}"
        # download_region_config "hk" "港|HK|Hong|HONG"
        # download_region_config "sg" "新|SG"
        # download_region_config "usa" "美|USA"

        # 下载专用下载节点配置
        if [ -n "$clash_download_url" ]; then
            download_region_config "download" "" "" "$clash_download_url"
        else
            download_region_config "download" "" "" "$clash_url"
        fi
    fi

    cp "$CLASH_DIR/$clash_config" "$CLASH_CONFIG"
fi

# 检查是否存在 proxies.yaml
if [ ! -f "$CLASH_DIR/proxies_default.yaml" ]; then
    echo "错误：未找到 proxies_default.yaml 文件，退出程序"
    exit 1
fi

# 检查文件中是否包含有效的代理节点配置
if ! grep -q "^[[:space:]]*-[[:space:]]*{.*name:.*server:.*port:.*type:" "$CLASH_DIR/proxies_default.yaml"; then
    echo "错误：proxies_default.yaml 文件中未找到有效的代理节点配置，退出程序"
    exit 1
fi

# 更新代理认证信息
sed -i "s|\"proxy_username:proxy_password\"|\"$proxy_username:$proxy_password\"|g" "$CLASH_CONFIG"

echo ""
echo "========================================================"
echo ""

# 显示配置信息
echo "当前 Clash 配置:"
cat "$CLASH_CONFIG"
echo ""
echo "========================================================"
echo ""
echo "当前 proxies_default.yaml 配置:"
[ -f "$CLASH_DIR/proxies_default.yaml" ] && cat "$CLASH_DIR/proxies_default.yaml"

echo ""
echo "========================================================"
echo ""

# 显示当前端口监听状态
echo "当前服务器监听端口:"
netstat -ntlpu

# 启动 clash
echo "启动 clash..."
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
nohup /usr/bin/mihomo -d "$CLASH_DIR" > "$LOG_FILE" 2>&1 &

echo "Clash 已启动，日志文件: $LOG_FILE"
