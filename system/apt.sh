#!/bin/bash

###################
# 配置和常量定义 #
###################

# 抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 文件路径定义
SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
LIST_FILE="/etc/apt/sources.list"
UPDATE_STAMP="/var/lib/apt/periodic/update-success-stamp"

# 中国源配置
CHINA_MIRROR="mirrors.ustc.edu.cn"
# 国际源配置
INTERNATIONAL_MIRROR="deb.debian.org"
SECURITY_MIRROR="security.debian.org"

###################
# 辅助函数定义   #
###################

# 显示使用方法
show_usage() {
    echo "用法: $0 [-cn|--china]"
    echo "选项:"
    echo "  -cn, --china    使用中国镜像源"
    exit 1
}

# 生成sources.list格式的内容
generate_list_content() {
    local mirror=$1
    local security_mirror=${2:-$mirror}

    cat << EOF
deb http://${mirror}/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://${mirror}/debian/ bookworm main contrib non-free non-free-firmware
deb http://${mirror}/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://${mirror}/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://${security_mirror}/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://${security_mirror}/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
}

# 生成sources格式的内容
generate_sources_content() {
    local mirror=$1
    local security_mirror=${2:-$mirror}

    cat << EOF
Types: deb
URIs: http://${mirror}/debian
Suites: bookworm
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://${security_mirror}/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://${mirror}/debian
Suites: bookworm-updates
Components: main contrib non-free non-free-firmware
EOF
}

# 检查是否需要更新
need_update() {
    # 如果更新标记文件不存在，则需要更新
    [ ! -f "$UPDATE_STAMP" ] && return 0

    # 计算距离上次更新的时间（秒）
    local last_update=$(stat -c %Y "$UPDATE_STAMP")
    local now=$(date +%s)
    local diff=$((now - last_update))

    # 如果超过120秒（2分钟），则需要更新
    [ $diff -gt 120 ]
}

# 备份并写入新配置
backup_and_write() {
    local target_file=$1
    local content=$2

    # 创建备份
    if [ -f "$target_file" ]; then
        echo "备份原始文件到 ${target_file}.bak ..."
        cp "$target_file" "${target_file}.bak"
    fi

    # 写入新配置
    echo "写入新的源配置到 $target_file ..."
    echo "$content" > "$target_file"

    echo "新的源配置："
    cat "$target_file"
}

# 执行更新和升级
do_update_upgrade() {
    if need_update; then
        echo "更新软件包列表..."
        apt-get update

        echo "升级软件包..."
        apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"
    else
        echo "距离上次更新不足2分钟，跳过更新..."
    fi
}

###################
# 主程序         #
###################

main() {
    # 解析命令行参数
    local use_cn=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -cn|--china)
                use_cn=true
                shift
                ;;
            *)
                show_usage
                ;;
        esac
    done

    # 确定使用的镜像
    if [ "$use_cn" = true ]; then
        mirror=$CHINA_MIRROR
        security_mirror=$CHINA_MIRROR
    else
        mirror=$INTERNATIONAL_MIRROR
        security_mirror=$SECURITY_MIRROR
    fi

    # 确定使用哪种配置文件
    if [ -f "$SOURCES_FILE" ]; then
        echo "使用 .sources 格式配置..."
        content=$(generate_sources_content "$mirror" "$security_mirror")
        target_file=$SOURCES_FILE
    else
        echo "使用 .list 格式配置..."
        content=$(generate_list_content "$mirror" "$security_mirror")
        target_file=$LIST_FILE
    fi

    # 执行配置更新
    backup_and_write "$target_file" "$content"

    # 执行系统更新
    do_update_upgrade

    echo "操作完成！"
}

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要root权限运行"
    echo "请使用 sudo $0"
    exit 1
fi

# 运行主程序
main "$@"
