#!/bin/bash
set -e

# 配置文件路径
MASTER_CONFIG_FILE="/etc/mysql/master.conf"
# 如何 配置文件不存在或者主机配置不存在退出
if [ ! -f "$MASTER_CONFIG_FILE" ]; then
  echo "错误: 配置文件 $MASTER_CONFIG_FILE 不存在!"
  exit 1
fi
source $MASTER_CONFIG_FILE

BACKUP_DIR="/backup"
DATE=$(date +%Y-%m-%d)
if [ -z "$MASTER_HOST" ]; then
  echo "错误: 主库主机配置不存在!"
  exit 1
fi

# 创建备份目录
mkdir -p $BACKUP_DIR

# 2. 使用 mysqldump 备份主库数据
echo "备份主库数据..."

if [ "$DATABASES_TO_BACKUP" = "all" ]; then
    # 备份所有数据库
    echo "备份所有业务数据库..."
    DATABASES=$(mysql -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" -s -N -e "SELECT GROUP_CONCAT(schema_name SEPARATOR ' ') FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys','__recycle_bin__','__cdb_recycle_bin__','__tencentdb__');")
    echo "$DATABASES"
    mysqldump -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" \
        --databases $DATABASES \
        --default-character-set=utf8mb4 \
        --triggers \
        --routines \
        --events \
        --set-gtid-purged=ON \
        --master-data=2 \
        --flush-logs \
        --single-transaction \
        --skip-add-locks \
        --skip-quote-names \
        --max-allowed-packet=128M \
        --net-buffer-length=1M \
        > "$BACKUP_DIR/mysql_backup_$DATE.sql"
else
    # 备份指定的数据库
    echo "备份指定数据库: $DATABASES_TO_BACKUP"
    mysqldump -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" \
        --databases $DATABASES_TO_BACKUP \
        --default-character-set=utf8mb4 \
        --triggers \
        --routines \
        --events \
        --set-gtid-purged=ON \
        --master-data=2 \
        --flush-logs \
        --single-transaction \
        --skip-add-locks \
        --skip-quote-names \
        --max-allowed-packet=128M \
        --net-buffer-length=1M \
        > "$BACKUP_DIR/mysql_backup_$DATE.sql"
fi

# 3. 提取 binlog 位置信息
echo "提取 binlog 位置信息..."
BINLOG_INFO=$(cat "$BACKUP_DIR/mysql_backup_$DATE.sql" | grep "CHANGE MASTER TO" | head -1)
MASTER_LOG_FILE=$(echo $BINLOG_INFO | grep -o "MASTER_LOG_FILE='[^']*'" | cut -d"'" -f2)
MASTER_LOG_POS=$(echo $BINLOG_INFO | grep -o "MASTER_LOG_POS=[0-9]*" | cut -d"=" -f2)

echo "Binlog 文件: $MASTER_LOG_FILE"
echo "Binlog 位置: $MASTER_LOG_POS"

# 输出 BINLOG_INFO MASTER_LOG_FILE MASTER_LOG_POS 到 /etc/mysql/master_backup.conf
cat > /etc/mysql/master_backup.conf <<EOF
BACKUP_FILE=$BACKUP_DIR/mysql_backup_$DATE.sql
BINLOG_INFO=$BINLOG_INFO
MASTER_LOG_FILE=$MASTER_LOG_FILE
MASTER_LOG_POS=$MASTER_LOG_POS
EOF

# 输出 /etc/mysql/master_backup.conf
cat /etc/mysql/master_backup.conf

echo ""
echo "===== 导出主库数据完成 ====="
echo ""
echo ""