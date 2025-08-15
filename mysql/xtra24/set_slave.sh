#!/bin/bash

# 从配置文件读取 MySQL root 密码
source /etc/mysql.conf
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_IP="localhost"
MYSQL_PORT="61786"

# 验证密码是否成功读取
if [ -z "$MYSQL_PASSWORD" ]; then
    echo "错误：无法从 /etc/mysql.conf 读取 MySQL root 密码"
    exit 1
fi

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

# 交互式输入主服务器信息
read -p "请输入主服务器IP [10.18.1.51]: " MASTER_MYSQL_IP
MASTER_MYSQL_IP=${MASTER_MYSQL_IP:-10.18.1.51}

read -p "请输入主服务器端口 [61786]: " MASTER_MYSQL_PORT
MASTER_MYSQL_PORT=${MASTER_MYSQL_PORT:-61786}

# 同步用户默认值
DEFAULT_SYNC_USER="slave_sync"

read -p "请输入同步用户 [${DEFAULT_SYNC_USER}]: " SYNC_USER
SYNC_USER=${SYNC_USER:-$DEFAULT_SYNC_USER}

# 输入同步密码（隐藏输入）
read -sp "请输入同步用户密码: " SYNC_PASSWORD
echo  # 换行

# 确认是否继续
read -p "是否确认恢复并设置主从同步？(y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "取消操作"
    exit 0
fi

# 设置从机ID
SLAVE_ID=$(shuf -i 1-1000000 -n 1)
echo "从机ID: $SLAVE_ID"
sed -i "s/^server-id = .*/server-id = $SLAVE_ID/g" /etc/my.cnf

# 获取GTID_PURGED
GTID_PURGED=$(awk '{print $3}' "$SELECTED_BACKUP_DIR/xtrabackup_binlog_info")

if [ -n "$GTID_PURGED" ]; then
    echo "GTID_PURGED: $GTID_PURGED"

    # 停止并重置主从同步
    mysql -h$MYSQL_IP -P$MYSQL_PORT -uroot -p$MYSQL_PASSWORD -e "stop slave;reset slave all;reset master;"

    # 重启MySQL
    service mysqld restart

    # 设置GTID_PURGED
    mysql -h$MYSQL_IP -P$MYSQL_PORT -uroot -p$MYSQL_PASSWORD -e "SET @@GLOBAL.GTID_PURGED='${GTID_PURGED}';show variables like '%gtid%';"

    # 配置主从同步
    mysql -h$MYSQL_IP -P$MYSQL_PORT -uroot -p$MYSQL_PASSWORD -e "change master to master_host='${MASTER_MYSQL_IP}',master_port=${MASTER_MYSQL_PORT},master_user='${SYNC_USER}',master_password='${SYNC_PASSWORD}',master_auto_position=1;"

    # 启动主从同步
    mysql -h$MYSQL_IP -P$MYSQL_PORT -uroot -p$MYSQL_PASSWORD -e "start slave;"
    sleep 3

    # 显示主从状态
    mysql -h$MYSQL_IP -P$MYSQL_PORT -uroot -p$MYSQL_PASSWORD -e "show master status\G;show slave status\G;"
else
    echo "GTID_PURGED 不能为空,请检查 $SELECTED_BACKUP_DIR/xtrabackup_binlog_info"
fi