#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "======================="
echo "  Debian 12 系统优化脚本  "
echo "======================="

# 函数：检查并设置 sysctl 参数
set_sysctl_param() {
    param=$1
    value=$2
    file="/etc/sysctl.conf"

    echo "正在将 $param 设置为 $value"

    if grep -Eq "^[# ]*$param" "$file"; then
        sudo sed -i "s|^[# ]*$param.*|$param = $value|" "$file"
    else
        echo "$param = $value" | sudo tee -a "$file" > /dev/null
    fi

    sudo sysctl -w "$param=$value" > /dev/null
    echo "$param 已设置为 $value 并立即生效"
}

# 函数：设置 limits.conf
configure_limits() {
    local limits_file="/etc/security/limits.conf"

    # 备份原始文件
    if [ ! -f "${limits_file}.bak" ]; then
        echo "备份 ${limits_file} 到 ${limits_file}.bak"
        sudo cp "$limits_file" "${limits_file}.bak"
    fi

    echo "配置系统限制..."

    # 创建临时文件
    local tmp_file=$(mktemp)

    # 写入新的 limits 配置
    cat << 'EOF' > "$tmp_file"
# /etc/security/limits.conf
#
# 系统资源限制配置
#

# 普通用户限制
*        soft    nproc          65535
*        hard    nproc          65535
*        soft    nofile         65535
*        hard    nofile         65535

# root 用户限制
root     soft    nproc          65535
root     hard    nproc          65535
root     soft    nofile         65535
root     hard    nofile         65535

# End of file
EOF

    # 替换原文件
    sudo mv "$tmp_file" "$limits_file"
    sudo chmod 644 "$limits_file"

    echo "系统限制配置完成"
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 权限运行此脚本"
    exit 1
fi

echo "开始系统优化..."

# 配置 limits.conf
configure_limits

# 网络和系统参数优化
declare -A system_params=(
    # 文件系统优化
    ["fs.file-max"]="1024000"
    ["fs.inotify.max_user_instances"]="8192"
    ["fs.inotify.max_user_watches"]="524288"

    # 网络优化
    ["net.ipv4.tcp_fin_timeout"]="30"
    ["net.ipv4.tcp_keepalive_time"]="1200"
    ["net.ipv4.tcp_max_syn_backlog"]="8192"
    ["net.ipv4.tcp_max_tw_buckets"]="5000"
    ["net.ipv4.tcp_fastopen"]="3"
    ["net.ipv4.tcp_rmem"]="4096 87380 67108864"
    ["net.ipv4.tcp_wmem"]="4096 65536 67108864"
    ["net.core.rmem_max"]="67108864"
    ["net.core.wmem_max"]="67108864"
    ["net.core.netdev_max_backlog"]="65536"
    ["net.core.somaxconn"]="32768"

    # IPv6 设置
    ["net.ipv6.conf.all.disable_ipv6"]="1"
    ["net.ipv6.conf.default.disable_ipv6"]="1"

    # 其他网络优化
    ["net.ipv4.ip_forward"]="1"
    ["net.ipv4.tcp_syncookies"]="1"
    ["net.ipv4.tcp_tw_reuse"]="1"
    ["net.ipv4.ip_local_port_range"]="1024 65000"

    # BBR 相关
    ["net.core.default_qdisc"]="fq"
    ["net.ipv4.tcp_congestion_control"]="bbr"

    # TCP 内存设置
    ["net.ipv4.tcp_mem"]="8388608 12582912 16777216"
    ["net.core.rmem_default"]="262144"
    ["net.core.wmem_default"]="262144"
    ["net.core.optmem_max"]="16777216"

    # TCP keepalive 设置
    ["net.ipv4.tcp_keepalive_intvl"]="30"
    ["net.ipv4.tcp_keepalive_probes"]="5"
)

# 设置所有参数
for param in "${!system_params[@]}"; do
    set_sysctl_param "$param" "${system_params[$param]}"
done

# 应用 sysctl 更改
echo "应用系统参数更改..."
sudo sysctl -p

# 检查 BBR 状态
echo "检查 BBR 状态..."
lsmod | grep bbr

# 添加 pam_limits.so 配置
echo "配置 PAM limits..."
if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session; then
    echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session > /dev/null
fi

if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session-noninteractive; then
    echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/common-session-noninteractive > /dev/null
fi

echo "系统优化完成。建议重启系统以使所有更改生效。"

# 显示当前系统限制
echo "当前系统限制状态："
ulimit -a
