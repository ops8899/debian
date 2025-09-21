#!/bin/bash

#==============================================================================
# MySQL 数据恢复脚本 (正确版本)
# 功能: 从备份文件恢复MySQL数据
# 版本: 1.0
#==============================================================================

: <<'EXAMPLES'
使用示例:

1. 基本恢复（使用配置文件密码）:
   ./restore.sh -f /backup/mydb_20241201.sql

2. 恢复压缩文件:
   ./restore.sh -f /backup/mydb_20241201.sql.gz

3. 指定连接参数:
   ./restore.sh -f /backup/mydb_20241201.sql -h localhost -P 3306 -u root -p mypassword

4. 强制执行（跳过确认）:
   ./restore.sh -f /backup/mydb_20241201.sql --force

EXAMPLES

show_usage() {
    echo "MySQL数据库恢复脚本"
    echo ""
    echo "使用方法: $0 -f BACKUP_FILE [选项]"
    echo ""
    echo "必需参数:"
    echo "  -f FILE        备份文件路径（支持.sql和.sql.gz格式）"
    echo ""
    echo "可选参数:"
    echo "  -h HOST        主机地址（默认：127.0.0.1）"
    echo "  -P PORT        端口号（默认：3306）"
    echo "  -u USER        用户名（默认：root）"
    echo "  -p PASSWORD    MySQL密码（可选，会自动从~/.my.cnf读取）"
    echo "  --force        强制执行，跳过所有确认提示"
    echo ""
    echo "示例:"
    echo "  $0 -f /backup/backup.sql"
    echo "  $0 -f /backup/backup.sql.gz --force"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 确认函数
confirm() {
    local prompt="$1"
    local default="$2"

    echo -n "$prompt" >&2
    read -r answer

    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]) return 1 ;;
        "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
        *) return 1 ;;
    esac
}

# 获取MySQL版本信息
get_mysql_version() {
    VERSION_STRING=$($TEST_MYSQL_CMD -s -N -e "SELECT VERSION();" 2>/dev/null)
    if [[ -n "$VERSION_STRING" ]]; then
        MAJOR_VERSION=$(echo "$VERSION_STRING" | cut -d. -f1)
        MINOR_VERSION=$(echo "$VERSION_STRING" | cut -d. -f2)
        log "MySQL版本: $VERSION_STRING (主版本: $MAJOR_VERSION, 次版本: $MINOR_VERSION)"
    else
        log "警告: 无法获取MySQL版本，使用默认配置"
        MAJOR_VERSION=5
        MINOR_VERSION=5
    fi
}

# 重置GTID状态函数
reset_gtid_status() {
    log "重置GTID状态以避免冲突"
    echo "正在重置GTID状态..."

    # 检查是否支持GTID（MySQL 5.6+）
    if [[ "$MAJOR_VERSION" -ge 6 ]] || [[ "$MAJOR_VERSION" -eq 5 && "$MINOR_VERSION" -ge 6 ]]; then
        $TEST_MYSQL_CMD <<EOF 2>>"$LOG_FILE"
STOP SLAVE;
RESET SLAVE ALL;
RESET MASTER;
EOF

        if [[ $? -eq 0 ]]; then
            log "GTID状态重置成功"
            echo "✓ GTID状态重置成功"
        else
            log "警告: GTID重置可能失败，但继续执行恢复"
            echo "⚠️  GTID重置可能失败，但继续执行恢复"
        fi
    else
        log "MySQL 5.5版本，跳过GTID重置"
        echo "✓ MySQL 5.5版本，跳过GTID重置"
    fi
}

# 初始化默认值
HOST="" PORT="" USER="" PASSWORD=""
BACKUP_FILE=""
USER_SPECIFIED=false
FORCE_MODE=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f) BACKUP_FILE="$2"; shift 2 ;;
        -h) HOST="$2"; shift 2 ;;
        -P) PORT="$2"; shift 2 ;;
        -u) USER="$2"; USER_SPECIFIED=true; shift 2 ;;
        -p) PASSWORD="$2"; shift 2 ;;
        --force) FORCE_MODE=true; shift ;;
        --help) show_usage; exit 0 ;;
        *) echo "未知参数: $1"; echo ""; show_usage; exit 1 ;;
    esac
done

# 参数校验
if [[ -z "$BACKUP_FILE" ]]; then
    echo "错误: 缺少备份文件参数！"
    show_usage
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "错误: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

# 创建日志目录并初始化日志
LOG_DIR="$(dirname "$0")/log"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/mysql_restore_$DATE.log"
START_TIME=$(date +%s)
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

log "========== MySQL 数据恢复开始 =========="

# 构建MySQL连接命令
MYSQL_CMD="mysql"
TEST_MYSQL_CMD="mysql"
[[ -n "$HOST" ]] && MYSQL_CMD="$MYSQL_CMD -h$HOST" && TEST_MYSQL_CMD="$TEST_MYSQL_CMD -h$HOST"
[[ -n "$PORT" ]] && MYSQL_CMD="$MYSQL_CMD -P$PORT" && TEST_MYSQL_CMD="$TEST_MYSQL_CMD -P$PORT"

if [[ "$USER_SPECIFIED" = true && -n "$PASSWORD" ]]; then
    MYSQL_CMD="$MYSQL_CMD -u$USER -p$PASSWORD"
    TEST_MYSQL_CMD="$TEST_MYSQL_CMD -u$USER -p$PASSWORD"
elif [[ "$USER_SPECIFIED" = true && -z "$PASSWORD" ]]; then
    MYSQL_CMD="$MYSQL_CMD -u$USER -p"
    TEST_MYSQL_CMD="$TEST_MYSQL_CMD -u$USER -p"
elif [[ -n "$PASSWORD" ]]; then
    MYSQL_CMD="$MYSQL_CMD -uroot -p$PASSWORD"
    TEST_MYSQL_CMD="$TEST_MYSQL_CMD -uroot -p$PASSWORD"
fi

# 显示连接信息
DISPLAY_HOST=${HOST:-"默认(配置文件或localhost)"}
DISPLAY_PORT=${PORT:-"默认(配置文件或3306)"}
DISPLAY_USER=${USER:-"默认(配置文件或当前用户)"}

log "目标库: $DISPLAY_HOST:$DISPLAY_PORT | 用户: $DISPLAY_USER"
log "备份文件: $(basename "$BACKUP_FILE") | 大小: $BACKUP_SIZE"

# 测试连接
echo "正在测试数据库连接..."
if [[ "$USER_SPECIFIED" = true && -z "$PASSWORD" ]]; then
    echo "请输入MySQL密码进行连接测试:"
fi

if ! $TEST_MYSQL_CMD -e "SELECT 1;" >/dev/null 2>&1; then
    log "错误: 数据库连接失败！"
    echo "✗ 连接失败，请检查连接参数或配置文件"
    exit 1
fi

echo "✓ 数据库连接成功"

# 获取MySQL版本信息
get_mysql_version

# 处理压缩文件
RESTORE_FILE="$BACKUP_FILE"
EXTRACTED=false

if [[ "$BACKUP_FILE" == *.gz ]]; then
    if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
        log "错误: 压缩文件损坏！"
        echo "✗ 备份文件验证失败"
        exit 1
    fi

    EXTRACT_FILE="${BACKUP_FILE%.gz}"
    log "解压文件到: $EXTRACT_FILE"

    if [[ -f "$EXTRACT_FILE" ]]; then
        if [[ "$FORCE_MODE" = false ]]; then
            echo "警告: 目标文件已存在: $EXTRACT_FILE"
            if ! confirm "是否覆盖现有文件？(y/N): " "n"; then
                echo "操作已取消"
                exit 0
            fi
        else
            log "强制模式: 覆盖现有文件 $EXTRACT_FILE"
        fi
    fi

    echo "正在解压文件..."
    gunzip -c "$BACKUP_FILE" > "$EXTRACT_FILE"
    if [[ $? -eq 0 ]]; then
        log "文件解压成功: $EXTRACT_FILE"
        RESTORE_FILE="$EXTRACT_FILE"
        EXTRACTED=true
    else
        log "文件解压失败！"
        echo "✗ 文件解压失败"
        exit 1
    fi
fi

# 确认恢复操作
if [[ "$FORCE_MODE" = false ]]; then
    echo ""
    echo "=========================================="
    echo "准备恢复数据到: $DISPLAY_HOST:$DISPLAY_PORT"
    echo "备份文件: $BACKUP_FILE ($BACKUP_SIZE)"
    if [[ "$EXTRACTED" = true ]]; then
        echo "解压文件: $RESTORE_FILE"
    fi
    echo "此操作将:"
    echo "1. 重置目标库的GTID状态"
    echo "2. 关闭binlog记录以提高性能"
    echo "3. 覆盖现有数据！"
    echo "=========================================="
    echo ""

    if ! confirm "确认继续恢复吗？(y/N): " "n"; then
        echo "操作已取消"
        exit 0
    fi
else
    log "强制模式: 跳过确认，直接执行恢复"
fi

# 重置GTID状态（关键步骤）
reset_gtid_status

# 执行恢复
log "开始恢复数据..."
echo "正在恢复数据，请稍候..."

if [[ "$USER_SPECIFIED" = true && -z "$PASSWORD" ]]; then
    echo "请输入MySQL密码进行数据恢复:"
fi

# 构建恢复命令，关闭binlog记录
RESTORE_MYSQL_CMD="$MYSQL_CMD --init-command=\"SET sql_log_bin=0;\""

# 根据MySQL版本添加额外参数
if [[ "$MAJOR_VERSION" -ge 8 ]] || [[ "$MAJOR_VERSION" -eq 5 && "$MINOR_VERSION" -ge 7 ]]; then
    # MySQL 5.7+ 支持更多选项
    RESTORE_MYSQL_CMD="$RESTORE_MYSQL_CMD --init-command=\"SET foreign_key_checks=0; SET unique_checks=0; SET autocommit=0;\""
    log "MySQL 5.7+: 启用优化参数（关闭外键检查、唯一性检查、自动提交、binlog记录）"
elif [[ "$MAJOR_VERSION" -eq 5 && "$MINOR_VERSION" -ge 6 ]]; then
    # MySQL 5.6 基本优化
    RESTORE_MYSQL_CMD="$RESTORE_MYSQL_CMD --init-command=\"SET foreign_key_checks=0; SET unique_checks=0;\""
    log "MySQL 5.6: 启用基本优化参数（关闭外键检查、唯一性检查、binlog记录）"
else
    # MySQL 5.5 最小配置
    log "MySQL 5.5: 使用基本配置（关闭binlog记录）"
fi

# 执行恢复
if command -v pv >/dev/null 2>&1; then
    log "使用pv显示恢复进度，关闭binlog记录"
    pv "$RESTORE_FILE" | eval "$RESTORE_MYSQL_CMD" 2>>"$LOG_FILE"
    RESTORE_RESULT=$?
else
    log "导入备份数据，关闭binlog记录"
    eval "$RESTORE_MYSQL_CMD" < "$RESTORE_FILE" 2>>"$LOG_FILE"
    RESTORE_RESULT=$?
fi

# 恢复后重新启用相关设置（如果需要）
if [[ $RESTORE_RESULT -eq 0 ]]; then
    log "恢复数据成功，重新启用相关设置"
    $TEST_MYSQL_CMD <<EOF 2>>"$LOG_FILE"
SET sql_log_bin=1;
SET foreign_key_checks=1;
SET unique_checks=1;
SET autocommit=1;
COMMIT;
EOF
fi

# 计算耗时并输出结果
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
HOURS=$((DURATION / 3600))
MINUTES=$(( (DURATION % 3600) / 60 ))
SECONDS=$((DURATION % 60))

if [[ $RESTORE_RESULT -ne 0 ]]; then
    log "恢复失败！请查看日志文件"
    echo "✗ 恢复失败，请查看日志: $LOG_FILE"

    # 显示错误信息
    echo ""
    echo "最近的错误信息:"
    tail -10 "$LOG_FILE"

    exit 1
fi

log "恢复成功！耗时: ${HOURS}小时${MINUTES}分钟${SECONDS}秒"
log "========== 恢复完成 =========="

echo ""
echo "✅ 恢复完成！"
echo "  备份文件: $BACKUP_FILE ($BACKUP_SIZE)"
if [[ "$EXTRACTED" = true ]]; then
    echo "  解压文件: $RESTORE_FILE"
fi
echo "  目标库: $DISPLAY_HOST:$DISPLAY_PORT"
echo "  MySQL版本: $VERSION_STRING"
echo "  耗时: ${HOURS}小时${MINUTES}分钟${SECONDS}秒"
echo "  日志: $LOG_FILE"

# 显示binlog信息（用于主从配置）
BINLOG_INFO=$(head -50 "$RESTORE_FILE" | grep -E "CHANGE MASTER TO.*MASTER_LOG_FILE.*MASTER_LOG_POS" | head -1)
if [[ -n "$BINLOG_INFO" ]]; then
    MASTER_LOG_FILE=$(echo "$BINLOG_INFO" | grep -o "MASTER_LOG_FILE='[^']*'" | cut -d"'" -f2)
    MASTER_LOG_POS=$(echo "$BINLOG_INFO" | grep -o "MASTER_LOG_POS=[0-9]*" | cut -d"=" -f2)
    echo "  Binlog位置: $MASTER_LOG_FILE:$MASTER_LOG_POS"
    log "Binlog位置: $MASTER_LOG_FILE:$MASTER_LOG_POS"
fi

echo ""
echo "如需配置主从复制，请使用: ./setup_slave.sh"

# 清理临时文件
if [[ "$EXTRACTED" = true && "$FORCE_MODE" = true ]]; then
    log "清理临时解压文件: $EXTRACT_FILE"
    rm -f "$EXTRACT_FILE"
fi
