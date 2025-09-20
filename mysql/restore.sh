#!/bin/bash

#==============================================================================
# MySQL 数据恢复脚本
# 功能: 从备份文件恢复MySQL数据，支持自动配置主从复制
# 版本: 1.0
#==============================================================================

#------------------------------------------------------------------------------
# 使用示例:
#------------------------------------------------------------------------------

: <<'EXAMPLES'

基本恢复:
./restore.sh -f /backup/backup.sql -p mypassword

恢复压缩文件:
./restore.sh -f /backup/backup.sql.gz -p mypassword

恢复并配置从库:
./restore.sh -f /backup/master.sql -p slavepass \
  --setup-slave --master-host 192.168.1.10 --master-port 3306 \
  --master-user repl --master-pass replpass

EXAMPLES

#------------------------------------------------------------------------------
# 注意事项:
#------------------------------------------------------------------------------

: <<'NOTES'

1. 备份文件必须是mysqldump生成的SQL文件，支持.gz压缩格式
2. 配置从库时，备份文件中必须包含binlog位置信息（--master-data=2）
3. 确保目标MySQL服务器已配置server-id和binlog
4. 主库必须已创建复制用户并授予REPLICATION SLAVE权限

生成兼容备份文件:
mysqldump -uroot -p --single-transaction --routines --triggers \
  --events --master-data=2 --all-databases > backup.sql

创建复制用户:
mysql -u root -p <<EOF
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
EOF

NOTES

show_usage() {
    echo "MySQL数据库恢复脚本"
    echo ""
    echo "使用方法: $0 -f BACKUP_FILE -p PASSWORD [选项]"
    echo ""
    echo "必需参数:"
    echo "  -f FILE        备份文件路径（支持.sql和.sql.gz格式）"
    echo "  -p PASSWORD    MySQL密码"
    echo ""
    echo "可选参数:"
    echo "  -h HOST        主机地址（默认：127.0.0.1）"
    echo "  -P PORT        端口号（默认：3306）"
    echo "  -u USER        用户名（默认：root）"
    echo "  --dry-run      仅验证不执行恢复"
    echo ""
    echo "主从复制参数:"
    echo "  --setup-slave  恢复后配置为从库"
    echo "  --master-host  主库地址"
    echo "  --master-port  主库端口（默认：3306）"
    echo "  --master-user  主库复制用户"
    echo "  --master-pass  主库复制密码"
    echo ""
    echo "示例:"
    echo "  $0 -f /backup/backup.sql -p mypassword"
    echo "  $0 -f /backup/master.sql -p slavepass --setup-slave --master-host 192.168.1.10 --master-port 3306 --master-user repl --master-pass replpass"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 初始化默认值
HOST="127.0.0.1" PORT="3306" USER="root" PASSWORD=""
BACKUP_FILE="" DRY_RUN=false
SETUP_SLAVE=false MASTER_HOST="" MASTER_PORT="3306" MASTER_USER="" MASTER_PASS=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f) BACKUP_FILE="$2"; shift 2 ;;
        -h) HOST="$2"; shift 2 ;;
        -P) PORT="$2"; shift 2 ;;
        -u) USER="$2"; shift 2 ;;
        -p) PASSWORD="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --setup-slave) SETUP_SLAVE=true; shift ;;
        --master-host) MASTER_HOST="$2"; shift 2 ;;
        --master-port) MASTER_PORT="$2"; shift 2 ;;
        --master-user) MASTER_USER="$2"; shift 2 ;;
        --master-pass) MASTER_PASS="$2"; shift 2 ;;
        --help) show_usage; exit 0 ;;
        *) echo "未知参数: $1"; echo ""; show_usage; exit 1 ;;
    esac
done

# 参数校验
if [[ -z "$BACKUP_FILE" || -z "$PASSWORD" ]]; then
    echo "错误: 缺少必需参数！"
    show_usage
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "错误: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

if [[ "$SETUP_SLAVE" = true ]]; then
    if [[ -z "$MASTER_HOST" || -z "$MASTER_USER" || -z "$MASTER_PASS" ]]; then
        echo "错误: 配置从库需要完整的主库连接信息！"
        show_usage
        exit 1
    fi
fi

# 初始化日志
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="mysql_restore_$DATE.log"
START_TIME=$(date +%s)
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

log "========== MySQL 数据恢复开始 =========="
log "目标库: $HOST:$PORT | 用户: $USER"
log "备份文件: $(basename "$BACKUP_FILE") | 大小: $BACKUP_SIZE"

# 测试连接
if ! mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
    log "错误: 数据库连接失败！请检查连接参数"
    echo "✗ 连接失败，请检查主机地址、端口、用户名和密码"
    exit 1
fi

# 验证备份文件格式
log "验证备份文件格式..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
        log "错误: 压缩文件损坏或格式错误！"
        echo "✗ 备份文件验证失败"
        exit 1
    fi
    FIRST_LINE=$(gunzip -c "$BACKUP_FILE" | head -1)
else
    FIRST_LINE=$(head -1 "$BACKUP_FILE")
fi

if [[ ! "$FIRST_LINE" =~ mysqldump|MySQL ]]; then
    log "警告: 文件可能不是mysqldump生成的备份文件"
fi

# 如果是干运行模式，只验证不执行
if [[ "$DRY_RUN" = true ]]; then
    log "干运行模式：验证完成，未执行实际恢复"
    echo "✓ 验证通过，文件格式正确"
    exit 0
fi

# 如果配置从库，先停止复制
if [[ "$SETUP_SLAVE" = true ]]; then
    log "停止从库复制..."
    mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -e "STOP SLAVE;" 2>/dev/null || true
fi

# 执行恢复
log "开始恢复数据..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    log "检测到压缩文件，解压恢复..."
    gunzip -c "$BACKUP_FILE" | mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" 2>>"$LOG_FILE"
else
    mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" < "$BACKUP_FILE" 2>>"$LOG_FILE"
fi

if [[ $? -ne 0 ]]; then
    log "恢复失败！请查看日志文件"
    echo "✗ 恢复失败，请查看日志: $LOG_FILE"
    exit 1
fi

log "数据恢复完成"

# 配置从库
if [[ "$SETUP_SLAVE" = true ]]; then
    log "配置从库复制..."

    # 从备份文件中提取binlog信息
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        BINLOG_LINE=$(gunzip -c "$BACKUP_FILE" | head -50 | grep -E "CHANGE MASTER TO.*MASTER_LOG_FILE.*MASTER_LOG_POS" | head -1)
    else
        BINLOG_LINE=$(head -50 "$BACKUP_FILE" | grep -E "CHANGE MASTER TO.*MASTER_LOG_FILE.*MASTER_LOG_POS" | head -1)
    fi

    if [[ -n "$BINLOG_LINE" ]]; then
        MASTER_LOG_FILE=$(echo "$BINLOG_LINE" | grep -o "MASTER_LOG_FILE='[^']*'" | cut -d"'" -f2)
        MASTER_LOG_POS=$(echo "$BINLOG_LINE" | grep -o "MASTER_LOG_POS=[0-9]*" | cut -d"=" -f2)

        if [[ -n "$MASTER_LOG_FILE" && -n "$MASTER_LOG_POS" ]]; then
            log "提取到Binlog信息: $MASTER_LOG_FILE:$MASTER_LOG_POS"

            mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -e "
            CHANGE MASTER TO
            MASTER_HOST='$MASTER_HOST',
            MASTER_PORT=$MASTER_PORT,
            MASTER_USER='$MASTER_USER',
            MASTER_PASSWORD='$MASTER_PASS',
            MASTER_LOG_FILE='$MASTER_LOG_FILE',
            MASTER_LOG_POS=$MASTER_LOG_POS;
            START SLAVE;"

            # 检查从库状态
            sleep 2
            SLAVE_STATUS=$(mysql -h"$HOST" -P"$PORT" -u"$USER" -p"$PASSWORD" -s -N -e "SHOW SLAVE STATUS\G" 2>/dev/null)

            if [[ -n "$SLAVE_STATUS" ]]; then
                SLAVE_IO=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')
                SLAVE_SQL=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')

                if [[ "$SLAVE_IO" == "Yes" && "$SLAVE_SQL" == "Yes" ]]; then
                    log "从库配置成功！"
                else
                    log "警告: 从库状态异常 (IO:$SLAVE_IO SQL:$SLAVE_SQL)"
                fi
            fi
        else
            log "警告: binlog信息提取失败，无法自动配置从库"
        fi
    else
        log "警告: 备份文件中未找到binlog位置信息"
        echo "备份文件可能不是使用 --master-data=2 参数生成的"
    fi
fi

# 计算耗时并输出结果
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log "恢复成功！耗时: ${MINUTES}分${SECONDS}秒"
log "========== 恢复完成 =========="

echo "✓ 恢复完成！"
echo "  文件: $BACKUP_FILE ($BACKUP_SIZE)"
echo "  目标: $HOST:$PORT"
echo "  耗时: ${MINUTES}分${SECONDS}秒"
echo "  日志: $LOG_FILE"

if [[ "$SETUP_SLAVE" = true ]]; then
    echo "  从库: 已配置连接到 $MASTER_HOST:$MASTER_PORT"
    echo ""
    echo "检查从库状态: mysql -h$HOST -P$PORT -u$USER -p -e \"SHOW SLAVE STATUS\\G\""
fi
