#!/bin/bash

# 检查是否为root
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行"
   exit 1
fi

# 安装必要工具
apt update
apt install -y parted fdisk dosfstools

# 获取系统盘
SYSTEM_DISK=$(df -h | grep '/$' | awk '{print $1}' | sed 's/[0-9]*$//')

# 获取所有磁盘
DISKS=$(lsblk -d -o NAME | grep -E '^sd|^vd' | grep -v "$(basename "$SYSTEM_DISK")")

# 显示可用磁盘
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

# 确认操作
read -p "确定要格式化 $DISK 吗? (yes/no): " confirm
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
mkdir -p /data

# 获取UUID
UUID=$(blkid ${DISK}1 | awk '{print $2}' | sed 's/"//g')

# 配置自动挂载
echo "$UUID /data ext4 defaults 0 2" >> /etc/fstab

# 立即挂载
mount -a

echo "磁盘初始化完成!"
