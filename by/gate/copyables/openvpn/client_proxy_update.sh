#!/bin/bash

# 函数：从URL中提取信息
parse_proxy_url() {
    local proxy_url="$1"

    # 移除协议前缀 (http:// 或 socks5://)
    proxy_url=$(echo "$proxy_url" | sed 's|^[^:]*://||')

    # 提取用户名密码和地址部分
    if [[ "$proxy_url" == *"@"* ]]; then
        # 有用户名密码
        local auth_part=$(echo "$proxy_url" | cut -d'@' -f1)
        local addr_part=$(echo "$proxy_url" | cut -d'@' -f2)

        username=$(echo "$auth_part" | cut -d':' -f1)
        password=$(echo "$auth_part" | cut -d':' -f2)
        host=$(echo "$addr_part" | cut -d':' -f1)
        port=$(echo "$addr_part" | cut -d':' -f2)
    else
        # 无用户名密码
        username=""
        password=""
        host=$(echo "$proxy_url" | cut -d':' -f1)
        port=$(echo "$proxy_url" | cut -d':' -f2)
    fi
}

# 函数：更新配置文件
update_config() {
    local config_file="$1"
    local proxy_type="$2"
    local proxy_url="$3"

    # 解析代理URL
    parse_proxy_url "$proxy_url"

    # 创建临时文件
    temp_file=$(mktemp)

    # 删除旧的代理配置
    sed '/^http-proxy /d; /^socks-proxy /d; /^http-proxy-option /d' "$config_file" > "$temp_file"

    # 添加新的代理配置
    if [[ "$proxy_type" == "http" ]]; then
        if [[ -n "$username" && -n "$password" ]]; then
            # 生成 base64 认证字符串
            auth_string=$(echo -n "$username:$password" | base64)
            {
                echo "http-proxy $host $port"
                echo "http-proxy-option CUSTOM-HEADER \"Proxy-Authorization: Basic $auth_string\""
            } >> "$temp_file"
        else
            echo "http-proxy $host $port" >> "$temp_file"
        fi
    elif [[ "$proxy_type" == "socks" || "$proxy_type" == "socks5" ]]; then
        if [[ -n "$username" && -n "$password" ]]; then
            echo "socks-proxy $host $port $username $password" >> "$temp_file"
        else
            echo "socks-proxy $host $port" >> "$temp_file"
        fi
    fi

    # 替换原文件
    mv "$temp_file" "$config_file"
    chmod --reference="$config_file.bak" "$config_file"
}

# 主函数
main() {
    local config_file="$1"
    local proxy_url="$2"

    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo "错误：配置文件 $config_file 不存在"
        exit 1
    fi

    # 检查配置文件是否可写
    if [ ! -w "$config_file" ]; then
        echo "错误：配置文件 $config_file 不可写"
        exit 1
    fi

    # 备份配置文件
    cp "$config_file" "$config_file.bak"

    # 判断代理类型并处理
    if [[ "$proxy_url" == http://* ]]; then
        update_config "$config_file" "http" "$proxy_url"
    elif [[ "$proxy_url" == socks5://* ]]; then
        update_config "$config_file" "socks" "$proxy_url"
    elif [[ "$proxy_url" != *://* ]]; then
        # 没有协议前缀，默认为HTTP
        update_config "$config_file" "http" "$proxy_url"
    fi

    echo "配置文件 代理服务器 $config_file 已更新"
    echo "备份文件保存为 $config_file.bak"
}

# 检查参数
if [ $# -ne 2 ]; then
    echo "使用方法: $0 <配置文件路径> <代理URL>"
    echo "示例:"
    echo "  $0 /etc/openvpn/client.ovpn http://user:pass@1.1.1.1:1080"
    echo "  $0 /etc/openvpn/client.ovpn user:pass@1.1.1.1:1080"
    echo "  $0 /etc/openvpn/client.ovpn 1.1.1.1:1080"
    echo "  $0 /etc/openvpn/client.ovpn socks5://user:pass@1.1.1.1:1081"
    exit 1
fi

# 运行主函数
main "$1" "$2"
