#!/bin/bash

CONFIG_FILE="/etc/mysql.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    read -sp "请输入MySQL密码: " MYSQL_ROOT_PASSWORD
    echo
    echo "MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" > "$CONFIG_FILE"
fi

source "$CONFIG_FILE"
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD

MYSQL_IP="localhost"
MYSQL_PORT="61786"

# 是否压缩,不压缩注释下一行
COMPRESS_CMD=" --compress --compress-threads=16 --slave-info "

# mysql 的数据目录
SAVE_PATH="/data/mysql"

# 备份目录
BACKUP_DIR="/data/backup/db/full/"

# 生成目标备份目录
TARGET_DIR="${BACKUP_DIR}/$(date +%Y-%m-%d-%H-%M-%S)"

mkdir -p $TARGET_DIR

# 执行 xtrabackup 备份
xtrabackup --defaults-file=/etc/my.cnf ${COMPRESS_CMD} --datadir=${SAVE_PATH} --host="${MYSQL_IP}" --user='root' --password="${MYSQL_PASSWORD}" --port=${MYSQL_PORT} --backup --target-dir="${TARGET_DIR}"

# 将 mysql.conf 拷贝到备份目录
cp /etc/mysql.conf "${TARGET_DIR}/mysql.conf"
