#!/bin/bash

#==============================================================================
# MySQL 数据库备份脚本
# 功能: 自动备份MySQL数据库，支持压缩、指定数据库等功能
# 版本: 1.0
# 日期: $(date '+%Y-%m-%d')
#==============================================================================

#------------------------------------------------------------------------------
# 使用示例 (可直接复制的命令):
#------------------------------------------------------------------------------

: <<'EXAMPLES'

基本备份（本地MySQL，备份所有业务库）:
./backup.sh -u root -p password123

远程MySQL备份:
./backup.sh -h 192.168.1.100 -P 3307 -u root -p password123

备份指定数据库并启用压缩:
./backup.sh -u root -p password123 -d "shop_db user_db" -c

自定义输出目录:
./backup.sh -u root -p password123 -o /data/mysql_backup

完整参数备份（生产环境推荐）:
./backup.sh -h 192.168.1.100 -P 3306 -u repl -p repl_pass \
  -d "ecommerce crm finance" -c -o /backup/mysql

指定mysqldump路径（非标准安装）:
./backup.sh -u root -p password123 -m /usr/local/mysql/bin/mysqldump

单个数据库备份:
./backup.sh -u root -p password123 -d "my_database"

大数据库压缩备份（节省空间）:
./backup.sh -u root -p password123 -c -o /backup/compressed

EXAMPLES

#------------------------------------------------------------------------------
# 创建备份专用用户示例:
#------------------------------------------------------------------------------

: <<'REPLICATION_USER_SETUP'
创建复制用户（具有所有权限，用于主从复制）:

mysql -u root -p <<EOF
-- 创建复制用户（如果不存在）
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_password';
-- 授予所有权限
GRANT ALL PRIVILEGES ON *.* TO 'repl'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

REPLICATION_USER_SETUP

show_usage() {
    echo "MySQL数据库备份脚本"
    echo ""
    echo "使用方法: $0 -u USER -p PASSWORD [选项]"
    echo ""
    echo "必需参数:"
    echo "  -u USER        MySQL用户名"
    echo "  -p PASSWORD    MySQL密码"
    echo ""
    echo "可选参数:"
    echo "  -h HOST        主机地址（默认：127.0.0.1）"
    echo "  -P PORT        端口号（默认：3306）"
    echo "  -d DATABASES   指定数据库（多个用空格分隔，默认备份所有业务库）"
    echo "  -c             启用gzip压缩（推荐用于大数据库）"
    echo "  -o DIR         输出目录（默认：/backup）"
    echo "  -m PATH        指定mysqldump路径（默认：mysqldump）"
    echo ""
    echo "常用示例:"
    echo "  # 基本备份"
    echo "  $0 -u root -p mypassword"
    echo ""
    echo "  # 压缩备份指定数据库"
    echo "  $0 -u root -p mypassword -d \"db1 db2\" -c"
    echo ""
    echo "  # 远程服务器备份"
    echo "  $0 -h 192.168.1.100 -u root -p mypassword -o /data/backup"
    echo ""
    echo "输出文件:"
    echo "  备份文件: mysql_backup_YYYY-MM-DD_HHMMSS.sql[.gz]"
    echo "  日志文件: mysql_backup_YYYY-MM-DD_HHMMSS.log"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 初始化默认值
HOST="127.0.0.1" PORT="3306" USER="" PASSWORD=""
DATABASES="" COMPRESS=false OUTPUT_DIR="/backup" MYSQLDUMP_BIN="mysqldump"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h) HOST="$2"; shift 2 ;;
        -P) PORT="$2"; shift 2 ;;
        -u) USER="$2"; shift 2 ;;
        -p) PASSWORD="$2"; shift 2 ;;
        -d) DATABASES="$2"; shift 2 ;;
        -c) COMPRESS=true; shift ;;
        -o) OUTPUT_DIR="$2"; shift 2 ;;
        -m) MYSQLDUMP_BIN="$2"; shift 2 ;;
        --help) show_usage; exit 0 ;;
        *) echo "未知参数: $1"; echo ""; show_usage; exit 1 ;;
    esac
done

# 参数校验
if [[ -z "$USER" || -z "$PASSWORD" ]]; then
    echo "错误: 缺少必需参数！"
    echo ""
    show_usage
    exit 1
fi

# 初始化
mkdir -p "$OUTPUT_DIR"
DATE=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE="$OUTPUT_DIR/mysql_backup_$DATE.log"
START_TIME=$(date +%s)

log "========== MySQL 备份开始 =========="
log "主机: $HOST:$PORT | 用户: $USER"
log "输出目录: $OUTPUT_DIR"
log "压缩模式: $([ "$COMPRESS" = true ] && echo "启用" || echo "禁用")"

# 测试连接并获取版本
MYSQL_VERSION=$(mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -s -N -e "SELECT VERSION();" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    log "错误: 数据库连接失败！请检查连接参数"
    echo "✗ 连接失败，请检查主机地址、端口、用户名和密码"
    exit 1
fi

log "MySQL版本: $MYSQL_VERSION"
MAJOR_VERSION=$(echo "$MYSQL_VERSION" | cut -d. -f1)
MINOR_VERSION=$(echo "$MYSQL_VERSION" | cut -d. -f2)

# 获取binlog位置
BINLOG_INFO=$(mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -s -N -e "SHOW MASTER STATUS;" 2>/dev/null)
if [[ -n "$BINLOG_INFO" ]]; then
    BINLOG_FILE=$(echo "$BINLOG_INFO" | awk '{print $1}')
    BINLOG_POS=$(echo "$BINLOG_INFO" | awk '{print $2}')
    log "Binlog位置: $BINLOG_FILE:$BINLOG_POS"
else
    log "警告: 未开启binlog或无权限查看"
fi

# 构建mysqldump命令
MYSQLDUMP_CMD="$MYSQLDUMP_BIN -h$HOST -P$PORT -u$USER -p$PASSWORD --single-transaction --routines --triggers --events --flush-logs --master-data=2"

# 根据版本设置字符集
if [[ "$MAJOR_VERSION" -ge 8 ]] || [[ "$MAJOR_VERSION" -eq 5 && "$MINOR_VERSION" -ge 7 ]]; then
    MYSQLDUMP_CMD="$MYSQLDUMP_CMD --set-gtid-purged=ON --default-character-set=utf8mb4"
else
    MYSQLDUMP_CMD="$MYSQLDUMP_CMD --default-character-set=utf8"
fi

# 确定数据库
if [[ -n "$DATABASES" ]]; then
    log "指定数据库: $DATABASES"
else
    DATABASES=$(mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -s -N -e "
    SELECT GROUP_CONCAT(schema_name SEPARATOR ' ')
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('information_schema','performance_schema','mysql','sys');" 2>/dev/null)

    if [[ -z "$DATABASES" ]]; then
        log "错误: 没有找到业务数据库或权限不足！"
        echo "✗ 未发现可备份的数据库，请检查权限或手动指定数据库"
        exit 1
    fi
    log "自动发现数据库: $DATABASES"
fi

MYSQLDUMP_CMD="$MYSQLDUMP_CMD --databases $DATABASES"

# 执行备份
if [[ "$COMPRESS" = true ]]; then
    BACKUP_FILE="$OUTPUT_DIR/mysql_backup_$DATE.sql.gz"
    log "开始压缩备份..."
    eval "$MYSQLDUMP_CMD" 2>>"$LOG_FILE" | gzip > "$BACKUP_FILE"
else
    BACKUP_FILE="$OUTPUT_DIR/mysql_backup_$DATE.sql"
    log "开始备份..."
    eval "$MYSQLDUMP_CMD" > "$BACKUP_FILE" 2>>"$LOG_FILE"
fi

# 检查结果
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

if [[ $? -eq 0 && -s "$BACKUP_FILE" ]]; then
    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "备份成功！文件: $(basename "$BACKUP_FILE") | 大小: $FILE_SIZE | 耗时: ${MINUTES}分${SECONDS}秒"
    log "========== 备份完成 =========="

    echo "✓ 备份完成！"
    echo "  文件: $BACKUP_FILE"
    echo "  大小: $FILE_SIZE"
    echo "  耗时: ${MINUTES}分${SECONDS}秒"
    echo "  数据库: $DATABASES"
    echo "  日志: $LOG_FILE"

    # 如果启用了压缩，显示压缩信息
    if [[ "$COMPRESS" = true ]]; then
        echo "  压缩: 已启用"
    fi
else
    log "备份失败！请检查错误信息"
    echo "✗ 备份失败，请查看日志: $LOG_FILE"
    exit 1
fi
