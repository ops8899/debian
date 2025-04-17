#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive

# 检查是否为root
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行"
   exit 1
fi

# 检查并安装缺失的工具
TOOLS=("parted" "fdisk" "mkfs.ext4")
PACKAGES=("parted" "fdisk" "dosfstools")

for i in ${!TOOLS[@]}; do
    if ! command -v ${TOOLS[i]} &> /dev/null; then
        echo "正在安装 ${PACKAGES[i]}..."
        apt update
        apt install -y ${PACKAGES[i]}
    fi
done

# 获取系统盘
SYSTEM_DISK=$(df -h | grep '/$' | awk '{print $1}' | sed 's/[0-9]*$//')

# 获取所有磁盘
DISKS=$(lsblk -d -o NAME | grep -E '^sd|^vd' | grep -v "$(basename "$SYSTEM_DISK")")

# 显示可用磁盘
echo "选择要初始化分区的磁盘:"
echo "可用磁盘:"
select DISK in $DISKS "退出"; do
    case $DISK in
        "退出")
            exit 0
            ;;
        *)
            if [[ -n $DISK ]]; then
                DISK="/dev/$DISK"
                break
            fi
            ;;
    esac
done

# 输入挂载目录
read -p "请输入挂载目录(默认为 /data): " MOUNT_DIR
MOUNT_DIR=${MOUNT_DIR:-/data}

# 检查挂载目录是否已存在
if [ -d "$MOUNT_DIR" ]; then
    read -p "目录 $MOUNT_DIR 已存在，是否继续? (yes/no): " dir_confirm
    if [[ $dir_confirm != "yes" ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 确认操作
read -p "确定要格式化 $DISK 并挂载到 $MOUNT_DIR 吗? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "操作已取消"
    exit 1
fi

# 清除所有分区
echo "清除磁盘分区..."
for i in $(seq 1 10); do
    parted -s $DISK rm $i 2>/dev/null
done

# 创建分区表
parted -s $DISK mklabel msdos

# 创建分区
parted -s $DISK mkpart primary ext4 1 100%

# 格式化
mkfs.ext4 -F ${DISK}1

# 创建挂载点
mkdir -p "$MOUNT_DIR"

# 获取UUID
UUID=$(blkid ${DISK}1 | awk '{print $2}' | sed 's/"//g')

# 配置自动挂载
echo "$UUID $MOUNT_DIR ext4 defaults 0 2" >> /etc/fstab

# 重新加载 systemd 配置
systemctl daemon-reload

# 立即挂载
mount -a

# 显示磁盘使用情况
df -hl

echo "磁盘初始化完成！挂载目录为 $MOUNT_DIR"
