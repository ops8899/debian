#!/bin/bash
set -e

# 生成id
bash /shell/generate_server_id.sh

# 配置文件路径
CONFIG_FILE_ROOT="/etc/mysql/root.conf"
CONFIG_FILE_REPL="/etc/mysql/repl.conf"
MASTER_CONFIG_FILE="/etc/mysql/master.conf"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE_ROOT" ]; then
    echo "配置文件 $CONFIG_FILE_ROOT 不存在，请先创建配置文件。"
    exit 1
fi

# 从配置文件中读取变量
source "$CONFIG_FILE_ROOT"

# 如果 repl 文件存在，就 source
if [ -f "$CONFIG_FILE_REPL" ]; then
    source "$CONFIG_FILE_REPL"
fi

# 检查是否存在上次的主机配置
if [ -f "$MASTER_CONFIG_FILE" ]; then
    source "$MASTER_CONFIG_FILE"
fi

# 定义参数默认值和命令行参数处理
MASTER_HOST="${1:-${MASTER_HOST:-localhost}}"
MASTER_PORT="${2:-${MASTER_PORT:-3306}}"
MASTER_USER="${3:-${MASTER_USER:-root}}"
MASTER_PASSWORD="${4:-${MASTER_PASSWORD:-$MYSQL_ROOT_PASSWORD}}"
MASTER_REPLICATION_USER="${5:-${MASTER_REPLICATION_USER:-repl}}"
MASTER_REPLICATION_PASSWORD="${6:-${MASTER_REPLICATION_PASSWORD:-Repl8899}}"
# 获取要备份的数据库参数，默认为"all"
DATABASES_TO_BACKUP="${7:-${DATABASES_TO_BACKUP:-all}}"

REPLICA_HOST="localhost"
REPLICA_PORT="3306"
BACKUP_DIR="/backup"
DATE=$(date +%Y-%m-%d)

# 确保必需的变量已设置
if [ -z "$MASTER_REPLICATION_USER" ] || [ -z "$MASTER_REPLICATION_PASSWORD" ]; then
    echo "复制用户或密码未设置，请检查 $CONFIG_FILE_ROOT。"
    exit 1
fi

# 保存主机配置（包括密码和要备份的数据库）
mkdir -p /etc/mysql
cat > "$MASTER_CONFIG_FILE" << EOF
# MySQL主库配置
MASTER_HOST="$MASTER_HOST"
MASTER_PORT="$MASTER_PORT"
MASTER_USER="$MASTER_USER"
MASTER_PASSWORD="$MASTER_PASSWORD"
MASTER_REPLICATION_USER="$MASTER_REPLICATION_USER"
MASTER_REPLICATION_PASSWORD="$MASTER_REPLICATION_PASSWORD"
DATABASES_TO_BACKUP="$DATABASES_TO_BACKUP"
EOF

# 设置文件权限，防止密码被其他用户读取
chmod 600 "$MASTER_CONFIG_FILE"

echo "===== 开始主从复制设置 ====="
echo "主库: $MASTER_HOST:$MASTER_PORT"
echo "主库用户: $MASTER_USER"
echo "从库: $REPLICA_HOST:$REPLICA_PORT"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 1. 在主库上创建复制用户(如果不存在)
echo "创建复制用户..."
mysql -h"$MASTER_HOST" -P"$MASTER_PORT" -u"$MASTER_USER" -p"$MASTER_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS '$MASTER_REPLICATION_USER'@'%' IDENTIFIED BY '$MASTER_REPLICATION_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO '$MASTER_REPLICATION_USER'@'%';
FLUSH PRIVILEGES;
EOF

# 2. 使用 mysqldump 备份主库数据
echo "备份主库数据..."

if [ "$DATABASES_TO_BACKUP" = "all" ]; then
    # 备份所有数据库
    echo "备份所有数据库..."
    mysqldump -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" \
        --all-databases \
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

# 4. 在从库上恢复数据

# 在从库上恢复数据前，先重置 GTID 状态
echo "重置从库 GTID 状态..."
mysql <<EOF
RESET MASTER;
EOF

echo "在从库上恢复数据..."
mysql < "$BACKUP_DIR/mysql_backup_$DATE.sql"

# 5. 检查主库 GTID 模式状态
echo "检查主库 GTID 状态..."
GTID_MODE=$(mysql -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" -e "SELECT @@GLOBAL.gtid_mode;" | grep -v "gtid_mode")
ENFORCE_GTID=$(mysql -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" -e "SELECT @@GLOBAL.enforce_gtid_consistency;" | grep -v "enforce_gtid_consistency")

if [[ "$GTID_MODE" != "ON" || "$ENFORCE_GTID" != "ON" ]]; then
    echo "警告: 主库未启用 GTID 模式或未强制 GTID 一致性"
    echo "GTID 模式: $GTID_MODE"
    echo "GTID 一致性: $ENFORCE_GTID"
    echo "请确保主库配置中包含:"
    echo "gtid_mode = ON"
    echo "enforce_gtid_consistency = ON"
fi

# 6. 配置从库复制
echo "配置从库复制..."
mysql <<EOF
STOP REPLICA;
CHANGE MASTER TO
  MASTER_HOST='$MASTER_HOST',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$MASTER_REPLICATION_USER',
  MASTER_PASSWORD='$MASTER_REPLICATION_PASSWORD',
  MASTER_LOG_FILE='$MASTER_LOG_FILE',
  MASTER_LOG_POS=$MASTER_LOG_POS;
START REPLICA;
EOF

# 7. 检查从库复制状态
echo "检查从库复制状态..."

echo "MySQL Master 状态:"
mysql  -h"$MASTER_HOST" -P"$MASTER_PORT" -u"root" -p"$MASTER_PASSWORD" <<EOF
show master status\G;
EOF

echo "MySQL Slave 状态:"
mysql <<EOF
show slave status\G;
EOF

# 初始化重试计数器
RETRY_COUNT=0
MAX_RETRIES=3
SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SUCCESS" != "true" ]; do
    # 获取复制状态
    REPLICA_STATUS=$(mysql -e "SHOW REPLICA STATUS\G")

    # 检查 IO 线程和 SQL 线程是否正常运行
    # 同时检查两种可能的输出格式
    IO_RUNNING=$(echo "$REPLICA_STATUS" | grep -E "Replica_IO_Running:|Slave_IO_Running:" | awk '{print $2}')
    SQL_RUNNING=$(echo "$REPLICA_STATUS" | grep -E "Replica_SQL_Running:|Slave_SQL_Running:" | awk '{print $2}')

    if [[ "$IO_RUNNING" == "Yes" && "$SQL_RUNNING" == "Yes" ]]; then
        SUCCESS=true
        echo "===== 主从复制设置成功! ====="
        echo "从库 IO 线程: $IO_RUNNING"
        echo "从库 SQL 线程: $SQL_RUNNING"
    else
        RETRY_COUNT=$((RETRY_COUNT+1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "从库复制状态检查未通过 (尝试 $RETRY_COUNT/$MAX_RETRIES)"
            echo "从库 IO 线程: $IO_RUNNING"
            echo "从库 SQL 线程: $SQL_RUNNING"
            echo "等待 3 秒后重试..."
            sleep 3
        fi
    fi
done

# 如果所有重试都失败，则显示错误信息
if [ "$SUCCESS" != "true" ]; then
    echo "===== 主从复制设置失败! ====="
    echo "从库 IO 线程: $IO_RUNNING"
    echo "从库 SQL 线程: $SQL_RUNNING"
    echo "错误详情:"
    echo "$REPLICA_STATUS" | grep -E "Last_IO_Error:|Last_SQL_Error:"
fi

cp /conf/slave.cnf /etc/mysql/conf.d/slave.cnf

echo ""
echo "===== 从机配置完成 ====="
echo ""
echo ""
echo "===== 请立即重启 MySQL 服务 ====="
echo ""
