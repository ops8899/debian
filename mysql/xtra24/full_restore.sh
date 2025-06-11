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
# mysql 的数据目录
SAVE_PATH="/data/mysql"

# 备份目录
BACKUP_DIR="/data/backup/db/full/"

# 列出备份目录下的子目录
echo "可用备份目录："
dirs=($(find "$BACKUP_DIR" -maxdepth 1 -type d | grep -v "^$BACKUP_DIR$" | sort))

for i in "${!dirs[@]}"; do
    echo "$((i+1)). ${dirs[i]}"
done

# 用户选择目录
read -p "请选择要恢复的备份目录(输入序号): " choice

# 验证输入
if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] || [ "$choice" -gt "${#dirs[@]}" ]; then
    echo "无效的选择"
    exit 1
fi

# 获取选择的目录
SELECTED_BACKUP_DIR="${dirs[$((choice-1))]}"

echo "你选择恢复的目录是: $SELECTED_BACKUP_DIR"

# 确认是否继续
read -p "是否确认恢复？(y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "取消恢复"
    exit 0
fi

# 停止 MySQL 服务
service mysqld stop

# 备份原数据目录
mv ${SAVE_PATH} ${SAVE_PATH}_$(date +%Y-%m-%d-%H-%M-%S)

# 解压和准备备份
xtrabackup --decompress --target-dir="${SELECTED_BACKUP_DIR}"
xtrabackup --defaults-file=/etc/my.cnf --prepare --target-dir="${SELECTED_BACKUP_DIR}"
xtrabackup --defaults-file=/etc/my.cnf --copy-back --target-dir="${SELECTED_BACKUP_DIR}"

# 修改权限
chown mysql:mysql $SAVE_PATH -fR

# 启动 MySQL 服务
service mysqld start

# 处理 mysql.conf 文件
mysql_conf_path="$SELECTED_BACKUP_DIR/mysql.conf"
# 检查文件是否存在
if [[ ! -f "$mysql_conf_path" ]]; then
    echo "错误：mysql.conf 文件不存在"
    exit 1
fi
sed -i 's/\r//g' "$SELECTED_BACKUP_DIR/mysql.conf"
cat $mysql_conf_path
source "$mysql_conf_path"
echo $MYSQL_ROOT_PASSWORD | od -c
echo "$MYSQL_ROOT_PASSWORD" | bt 7
cp $SELECTED_BACKUP_DIR/mysql.conf /etc/mysql.conf

sed -i 's|^password\s*=.*|password = '"$MYSQL_ROOT_PASSWORD"'|g' /etc/my.cnf

# 生成新的 uuid，避免与主服务器冲突
new_uuid=$(cat /proc/sys/kernel/random/uuid)
cat /data/mysql/auto.cnf
echo -e "[auto]\nserver-uuid=$new_uuid" > $SAVE_PATH/auto.cnf
cat $SAVE_PATH/auto.cnf

# 重启 MySQL 服务
service mysqld restart

# 获取 GTID_PURGED
GTID_PURGED=$(awk '{print $3}' "$SELECTED_BACKUP_DIR/xtrabackup_binlog_info")
echo "GTID_PURGED: $GTID_PURGED"
