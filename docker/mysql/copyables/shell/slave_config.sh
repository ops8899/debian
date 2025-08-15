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

MASTER_BACKUP_FILE="/etc/mysql/master_backup.conf"
# 如何 配置文件不存在或者主机配置不存在退出
if [ ! -f "$MASTER_BACKUP_FILE" ]; then
  echo "错误: 配置文件 $MASTER_BACKUP_FILE 不存在!"
  exit 1
fi
source  $MASTER_BACKUP_FILE

if [ -z "$MASTER_HOST" ]; then
  echo "错误: 主库主机配置不存在!"
  exit 1
fi

# 在从库上恢复数据前，停止从库复制，重置 GTID 状态
echo "停止从库复制，重置从库 GTID 状态..."
mysql <<EOF
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
EOF

# 如何 配置文件不存在或者主机配置不存在退出
if [ ! -f "$BACKUP_FILE" ]; then
  echo "错误: 配置文件 $BACKUP_FILE 不存在!"
  exit 1
fi

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
CHANGE MASTER TO
  MASTER_HOST='$MASTER_HOST',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$MASTER_REPLICATION_USER',
  MASTER_PASSWORD='$MASTER_REPLICATION_PASSWORD',
  MASTER_LOG_FILE='$MASTER_LOG_FILE',
  MASTER_LOG_POS=$MASTER_LOG_POS,
  MASTER_CONNECT_RETRY=10,
  MASTER_RETRY_COUNT=86400;
START SLAVE;
SELECT SLEEP(3);
SHOW SLAVE STATUS\G;
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
