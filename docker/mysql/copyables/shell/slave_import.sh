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

# 记录开始时间
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
START_SECONDS=$(date +%s)

echo ""
echo "在从库上恢复数据..."

# 添加错误检查
if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 备份文件 $BACKUP_FILE 不存在!"
    exit 1
fi

# 显示备份文件大小信息
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "备份文件大小: $BACKUP_SIZE"

# 执行恢复操作并检查结果
mysql < "$BACKUP_FILE"
RESTORE_STATUS=$?

# 记录结束时间
END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
END_SECONDS=$(date +%s)

# 计算耗时（秒）
DURATION=$((END_SECONDS - START_SECONDS))
# 转换为更易读的时分秒格式
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))
SECONDS=$((DURATION % 60))

echo ""
echo "数据恢复操作完成"
echo "开始时间: $START_TIME"
echo "结束时间: $END_TIME"
echo "总耗时: ${HOURS}小时 ${MINUTES}分钟 ${SECONDS}秒"

# 检查恢复是否成功
if [ $RESTORE_STATUS -eq 0 ]; then
    echo "恢复状态: 成功"
else
    echo "恢复状态: 失败 (错误代码: $RESTORE_STATUS)"
fi
