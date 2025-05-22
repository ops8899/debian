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

# 在从库上恢复数据前，先重置 GTID 状态
echo "重置从库 GTID 状态..."
mysql <<EOF
RESET MASTER;
EOF

# 如何 配置文件不存在或者主机配置不存在退出
if [ ! -f "$BACKUP_FILE" ]; then
  echo "错误: 配置文件 $BACKUP_FILE 不存在!"
  exit 1
fi

echo "在从库上恢复数据..."
mysql < "$BACKUP_FILE"


echo ""
echo "===== 在从库上恢复数据完成 ====="
echo ""
echo ""
