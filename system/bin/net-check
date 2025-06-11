#!/bin/bash

# 文件名: net-check

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请以root权限运行此脚本${NC}"
        exit 1
    fi
}

# 显示分隔线
show_separator() {
    echo -e "${BLUE}========================================${NC}"
}

# 显示标题
show_title() {
    show_separator
    echo -e "${GREEN}$1${NC}"
    show_separator
}

# 显示已建立的TCP连接统计
show_established_connections() {
    show_title "活动连接统计"
    echo -e "${YELLOW}远程IP连接数量统计：${NC}"
    ss -tnp state established | grep -v "127.0.0.1" | \
    awk 'NR>1 {
        split($4,peer,":");
        print peer[1]
    }' | sort | uniq -c | sort -nr

    echo -e "\n${YELLOW}详细连接信息：${NC}"
    ss -tnp state established | grep -v "127.0.0.1" | \
    awk 'NR>1 {
        split($3,local,":");
        split($4,peer,":");
        printf "本地: %-21s 远程: %-21s 进程: %s\n",
        $3, $4, $NF
    }'
}

# 显示监听端口
show_listening_ports() {
    show_title "监听端口信息"
    echo -e "${YELLOW}TCP端口：${NC}"
    ss -tlnp | awk 'NR>1 {printf "%-20s %-s\n", $4, $NF}'
    echo -e "\n${YELLOW}UDP端口：${NC}"
    ss -ulnp | awk 'NR>1 {printf "%-20s %-s\n", $4, $NF}'
}

# 显示网络相关进程
show_network_processes() {
    show_title "网络相关进程"
    echo -e "${YELLOW}常用网络服务进程：${NC}"
    ps aux | grep -E "nginx|apache|ssh|mysql|redis|mongodb|docker|containerd" | grep -v grep

    echo -e "\n${YELLOW}占用网络带宽较高的进程：${NC}"
    iotop -b -n 1 2>/dev/null || echo "iotop未安装，请使用 apt install iotop 安装"
}

# 显示当前连接状态统计
show_connection_stats() {
    show_title "连接状态统计"
    ss -s
}

# 显示网络接口信息
show_interface_info() {
    show_title "网络接口信息"

    # 显示接口概览
    echo -e "${YELLOW}接口概览：${NC}"
    ip -br addr

    # 显示详细接口信息
    echo -e "\n${YELLOW}详细接口信息：${NC}"
    ip addr show

    # 显示接口统计
    echo -e "\n${YELLOW}接口统计：${NC}"
    netstat -i

    # 显示网络配置文件
    echo -e "\n${YELLOW}网络配置文件：${NC}"
    if [ -f "/etc/network/interfaces" ]; then
        echo -e "\n=== /etc/network/interfaces ==="
        cat /etc/network/interfaces
    fi

    if [ -d "/etc/network/interfaces.d" ]; then
        echo -e "\n=== /etc/network/interfaces.d/ 目录下的配置文件 ==="
        for file in /etc/network/interfaces.d/*; do
            if [ -f "$file" ]; then
                echo -e "\n--- $(basename "$file") ---"
                cat "$file"
            fi
        done
    fi

    # 显示 Netplan 配置（如果存在）
    if [ -d "/etc/netplan" ]; then
        echo -e "\n${YELLOW}Netplan配置文件：${NC}"
        for file in /etc/netplan/*.yaml; do
            if [ -f "$file" ]; then
                echo -e "\n=== $(basename "$file") ==="
                cat "$file"
            fi
        done
    fi
}

# 显示路由表信息
show_routing_info() {
    show_title "路由表信息"

    # 显示路由策略规则
    echo -e "${YELLOW}路由策略规则（优先级说明）：${NC}"
    echo "数字越小优先级越高，系统默认规则如下："
    echo "0: 从本地路由表查找（系统保留）"
    echo "32766: 从主路由表查找（默认规则）"
    echo "32767: 从本地路由表查找（默认规则）"
    echo -e "\n${YELLOW}当前系统路由策略：${NC}"
    ip rule list

    # 显示本地路由表（local table）
    echo -e "\n${YELLOW}本地路由表（表255）：${NC}"
    echo "用于本地和广播地址的特殊路由表，包含以下类型路由："
    echo "- 接口地址（interface addresses）"
    echo "- 广播地址（broadcast addresses）"
    echo "- NAT地址（NAT addresses）"
    echo "- 本地网络路由（local network routes）"
    ip route show table local

    # 显示主路由表（main table）
    echo -e "\n${YELLOW}主路由表（表254）：${NC}"
    echo "用于普通路由转发的默认路由表，包含："
    echo "- 默认路由（default routes）"
    echo "- 网络路由（network routes）"
    echo "- 手动配置的静态路由（static routes）"
    ip route show table main

    # 遍历其他自定义路由表
    if [ -f "/etc/iproute2/rt_tables" ]; then
        while read -r line; do
            # 跳过注释、空行和系统预定义表
            [[ "$line" =~ ^#.*$ ]] || [ -z "$line" ] || \
            [[ "$line" =~ (255|254|253|0)[[:space:]] ]] && continue

            table_id=$(echo "$line" | awk '{print $1}')
            table_name=$(echo "$line" | awk '{print $2}')

            if ip route show table $table_id | grep -q .; then
                echo -e "\n${YELLOW}路由表 $table_name (ID: $table_id)：${NC}"
                ip route show table $table_id
            fi
        done < "/etc/iproute2/rt_tables"
    fi
}

# 显示DNS信息
show_dns_info() {
    show_title "DNS配置信息"
    echo -e "${YELLOW}resolv.conf内容：${NC}"
    cat /etc/resolv.conf

    echo -e "\n${YELLOW}本地hosts文件：${NC}"
    cat /etc/hosts | grep -v '^#' | grep -v '^$'
}

# 显示防火墙规则
show_firewall_rules() {
    show_title "防火墙规则"

    # 显示底层的 iptables 规则
    if command -v iptables >/dev/null 2>&1; then
        echo -e "\n${YELLOW}IPTables 底层规则：${NC}"
        echo "注：这些是包括 UFW 在内的所有防火墙规则的底层实现"

        # Filter表（默认表，管理数据包过滤）
        echo -e "\n${YELLOW}Filter表 (过滤规则)：${NC}"
        echo "作用：控制数据包是否允许进入、转发或离开系统"
        if iptables -L -n -v | grep -q "Chain"; then
            iptables -L -n -v --line-numbers
        else
            echo "Filter表无规则"
        fi

        # NAT表（网络地址转换）
        echo -e "\n${YELLOW}NAT表 (网络地址转换)：${NC}"
        echo "作用：修改数据包的源和目标地址"
        if iptables -t nat -L -n -v | grep -q "Chain"; then
            iptables -t nat -L -n -v --line-numbers
        else
            echo "NAT表无规则"
        fi

        # Mangle表（数据包修改）
        echo -e "\n${YELLOW}Mangle表 (数据包修改)：${NC}"
        echo "作用：修改数据包的服务类型、TTL等特殊数据包修改操作"
        if iptables -t mangle -L -n -v | grep -q "Chain"; then
            iptables -t mangle -L -n -v --line-numbers
        else
            echo "Mangle表无规则"
        fi

        # Raw表（连接跟踪）
        echo -e "\n${YELLOW}Raw表 (连接跟踪)：${NC}"
        echo "作用：配置免除连接跟踪的规则"
        if iptables -t raw -L -n -v | grep -q "Chain"; then
            iptables -t raw -L -n -v --line-numbers
        else
            echo "Raw表无规则"
        fi
    else
        echo -e "\niptables未安装，可以使用 'apt install iptables' 安装"
    fi

    # 检查并显示 UFW 状态
    if command -v ufw >/dev/null 2>&1; then
        echo -e "${YELLOW}UFW 防火墙状态：${NC}"
        if systemctl is-active --quiet ufw; then
            echo -e "${GREEN}UFW 已启用${NC}"
        else
            echo -e "${RED}UFW 未启用${NC}"
        fi

        echo -e "\n${YELLOW}UFW 详细状态：${NC}"
        ufw status verbose

    else
        echo "UFW未安装，可以使用 'apt install ufw' 安装"
    fi

    # 显示当前活动的网络连接
    echo -e "\n${YELLOW}活动的网络连接：${NC}"
    echo "状态  本地地址:端口        远程地址:端口"
    ss -tuln | grep "LISTEN" | awk '{printf "%-6s %-20s %-20s\n", $1, $5, $6}'
}

# 显示系统网络参数
show_sysctl_network() {
    show_title "系统网络参数"
    echo -e "${YELLOW}重要网络参数：${NC}"
    sysctl -a | grep -E "net.ipv4.ip_forward|net.ipv4.tcp_syncookies|net.ipv4.tcp_max_syn_backlog|net.ipv4.tcp_fin_timeout|net.ipv4.tcp_keepalive_time"
}

# 显示所有信息
show_all_info() {
    clear
    echo -e "${GREEN}网络连接监控报告${NC}"
    echo -e "${GREEN}生成时间：$(date)${NC}"
    show_separator

    show_established_connections
    show_listening_ports
    show_network_processes
    show_connection_stats
    show_interface_info
    show_routing_info
    show_dns_info
    show_firewall_rules
    show_sysctl_network
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}网络检查工具使用说明${NC}"
    echo "用法: net-check [选项]"
    echo
    echo "选项:"
    echo "  1    显示活动连接统计"
    echo "  2    显示监听端口"
    echo "  3    显示网络相关进程"
    echo "  4    显示连接状态统计"
    echo "  5    显示网络接口信息"
    echo "  6    显示路由表信息"
    echo "  7    显示DNS配置"
    echo "  8    显示防火墙规则"
    echo "  9    显示系统网络参数"
    echo "  99   显示所有信息"
    echo "  -h   显示此帮助信息"
    echo
    echo "示例:"
    echo "  net-check 99    # 显示所有网络信息"
    echo "  net-check 1     # 只显示活动连接统计"
    echo
}

# 主程序
main() {
    check_root

    # 如果没有参数，显示帮助信息
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # 处理命令行参数
    case "$1" in
        1) show_established_connections ;;
        2) show_listening_ports ;;
        3) show_network_processes ;;
        4) show_connection_stats ;;
        5) show_interface_info ;;
        6) show_routing_info ;;
        7) show_dns_info ;;
        8) show_firewall_rules ;;
        9) show_sysctl_network ;;
        99) show_all_info ;;
        -h|--help) show_help ;;
        *)
            echo -e "${RED}错误：无效的参数${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"
