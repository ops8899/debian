#!/bin/bash

# mysql root 密码
source /etc/mysql.conf
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_IP="127.0.0.1"
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

# 生成新的 uuid，避免与主服务器冲突
cat /data/mysql/auto.cnf
new_uuid=$(mysql -e "select uuid()" -N)
echo -e "[auto]\nserver-uuid=$new_uuid" > $SAVE_PATH/auto.cnf
cat $SAVE_PATH/auto.cnf

# 重启 MySQL 服务
service mysqld restart

# 获取 GTID_PURGED
GTID_PURGED=$(awk '{print $3}' "$SELECTED_BACKUP_DIR/xtrabackup_binlog_info")
echo "GTID_PURGED: $GTID_PURGED"
