#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 默认值设置
CN_MODE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -cn|--china)
            CN_MODE=true
            shift
            ;;
        *)
            echo "未知参数: $1"
            echo "用法: $0 [-cn|--china]"
            exit 1
            ;;
    esac
done

# 国内和国际源内容定义
CHINA_SOURCES_LIST="deb http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware"

CHINA_SOURCES_JSON="Types: deb
URIs: http://mirrors.ustc.edu.cn/debian
Suites: bookworm
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://mirrors.ustc.edu.cn/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://mirrors.ustc.edu.cn/debian
Suites: bookworm-updates
Components: main contrib non-free non-free-firmware"

INTERNATIONAL_SOURCES_LIST="deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware"

INTERNATIONAL_SOURCES_JSON="Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm-updates
Components: main contrib non-free non-free-firmware"

# 检测是否存在 .sources 文件或 .list 文件
SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
LIST_FILE="/etc/apt/sources.list"

if [[ -f "$SOURCES_FILE" ]]; then
    echo "检测到 $SOURCES_FILE 文件，优先使用 .sources 文件进行配置..."
    BACKUP_FILE="${SOURCES_FILE}.bak"
    CONTENT=$([[ $CN_MODE == true ]] && echo "$CHINA_SOURCES_JSON" || echo "$INTERNATIONAL_SOURCES_JSON")
elif [[ -f "$LIST_FILE" ]]; then
    echo "检测到 $LIST_FILE 文件，使用 .list 文件进行配置..."
    BACKUP_FILE="${LIST_FILE}.bak"
    CONTENT=$([[ $CN_MODE == true ]] && echo "$CHINA_SOURCES_LIST" || echo "$INTERNATIONAL_SOURCES_LIST")
else
    echo "未检测到 .sources 或 .list 文件，无法配置源！"
    exit 1
fi

# 备份并写入新的源配置
echo "备份原始文件到 $BACKUP_FILE..."
cp "$BACKUP_FILE" "${BACKUP_FILE}.bak"

echo "写入新的源配置..."
echo "$CONTENT" > "$BACKUP_FILE"

echo "新的源已配置："
cat "$BACKUP_FILE"

# 更新软件包列表并升级
echo "更新软件包列表..."
apt-get update

echo "升级软件包..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo "操作完成！"
