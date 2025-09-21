#!/bin/bash

#==============================================================================
# MySQL 主从复制配置脚本
# 功能: 配置MySQL从库，支持从备份文件自动提取binlog位置，自动修改server-id
# 版本: 1.0
# 兼容: MySQL 5.5/5.7/8.0
#==============================================================================

#------------------------------------------------------------------------------
# 使用示例:
#------------------------------------------------------------------------------

: <<'EXAMPLES'

从备份文件配置主从:
./slave_setup.sh -f /backup/master.sql -p slavepass --master-host 192.168.1.10 --master-user repl --master-pass replpass

手动指定binlog位置:
./slave_setup.sh --master-log-file mysql-bin.000001 --master-log-pos 154 -p slavepass --master-host 192.168.1.10 --master-user repl --master-pass replpass

查看从库状态:
./slave_setup.sh --status -p slavepass

配置远程从库:
./slave_setup.sh -h 192.168.1.20 -p slavepass -f /backup/master.sql --master-host 192.168.1.10 --master-user repl --master-pass replpass

使用配置文件认证（无密码）:
./slave_setup.sh -f /backup/master.sql --master-host 192.168.1.10 --master-user repl

EXAMPLES

#------------------------------------------------------------------------------
# 注意事项:
#------------------------------------------------------------------------------

: <<'NOTES'

1. 备份文件必须使用 --master-data=2 参数生成，支持.gz压缩格式
2. 脚本会自动生成随机server-id并修改配置文件
3. 配置文件会自动备份为 my.cnf.bak.时间戳
4. 支持密码为空的情况，使用MySQL配置文件认证
5. 主库需要提前创建复制用户并授权

生成兼容备份文件:
mysqldump -uroot -p --single-transaction --routines --triggers \
  --events --master-data=2 --all-databases > master.sql

创建复制用户:
# MySQL 5.5/5.7 (会自动创建用户)
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;

# MySQL 8.0 (需要先创建用户)
CREATE USER 'repl'@'%' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

NOTES

#------------------------------------------------------------------------------
# 脚本代码:
#------------------------------------------------------------------------------

show_usage() {
    echo "MySQL主从复制配置脚本"
    echo ""
    echo "使用方法: $0 [选项]"
    echo ""
    echo "从库连接参数:"
    echo "  -h HOST              从库地址（默认：127.0.0.1）"
    echo "  -P PORT              从库端口（默认：3306）"
    echo "  -u USER              从库用户（默认：root）"
    echo "  -p PASS              从库密码（可选）"
    echo ""
    echo "主库连接参数:"
    echo "  --master-host HOST   主库地址"
    echo "  --master-port PORT   主库端口（默认：3306）"
    echo "  --master-user USER   主库复制用户"
    echo "  --master-pass PASS   主库复制密码（可选）"
    echo ""
    echo "binlog位置参数（二选一）:"
    echo "  -f FILE              从备份文件自动提取binlog位置"
    echo "  --master-log-file    手动指定binlog文件名"
    echo "  --master-log-pos     手动指定binlog位置"
    echo ""
    echo "其他参数:"
    echo "  --config-file FILE   MySQL配置文件路径（默认：/etc/my.cnf）"
    echo "  --status             仅查看从库状态"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

generate_server_id() {
    echo $((10000000 + RANDOM % 90000000))
}

update_server_id() {
    local config_file=$1 new_server_id=$2
    [[ ! -f "$config_file" ]] && { log "配置文件不存在: $config_file"; return 1; }

    cp "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"

    if grep -q "^\s*server-id\s*=" "$config_file"; then
        sed -i "s/^\s*server-id\s*=.*/server-id = $new_server_id/" "$config_file"
    elif grep -q "^\[mysqld\]" "$config_file"; then
        sed -i "/^\[mysqld\]/a server-id = $new_server_id" "$config_file"
    else
        echo -e "\n[mysqld]\nserver-id = $new_server_id" >> "$config_file"
    fi
    log "设置server-id: $new_server_id"
}

restart_mysql() {
    log "重启MySQL..."
    if command -v systemctl >/dev/null; then
        systemctl restart mysqld || systemctl restart mysql
    else
        service mysqld restart || service mysql restart
    fi
    sleep 3
}

# 默认值
SLAVE_HOST="127.0.0.1" SLAVE_PORT="3306" SLAVE_USER="root" SLAVE_PASS=""
MASTER_HOST="" MASTER_PORT="3306" MASTER_USER="" MASTER_PASS=""
BACKUP_FILE="" MASTER_LOG_FILE="" MASTER_LOG_POS=""
CONFIG_FILE="/etc/my.cnf" SHOW_STATUS=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -f) BACKUP_FILE="$2"; shift 2 ;;
        -h) SLAVE_HOST="$2"; shift 2 ;;
        -P) SLAVE_PORT="$2"; shift 2 ;;
        -u) SLAVE_USER="$2"; shift 2 ;;
        -p) SLAVE_PASS="$2"; shift 2 ;;
        --master-host) MASTER_HOST="$2"; shift 2 ;;
        --master-port) MASTER_PORT="$2"; shift 2 ;;
        --master-user) MASTER_USER="$2"; shift 2 ;;
        --master-pass) MASTER_PASS="$2"; shift 2 ;;
        --master-log-file) MASTER_LOG_FILE="$2"; shift 2 ;;
        --master-log-pos) MASTER_LOG_POS="$2"; shift 2 ;;
        --config-file) CONFIG_FILE="$2"; shift 2 ;;
        --status) SHOW_STATUS=true; shift ;;
        --help) show_usage; exit 0 ;;
        *) echo "未知参数: $1"; show_usage; exit 1 ;;
    esac
done

# 创建日志目录并设置日志文件路径
LOG_DIR="$(dirname "$0")/log"
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mysql_slave_setup_$(date +%Y%m%d_%H%M%S).log"

# 构建MySQL命令 - 修复密码参数问题
if [[ -n "$SLAVE_PASS" ]]; then
    SLAVE_CMD="mysql -h$SLAVE_HOST -P$SLAVE_PORT -u$SLAVE_USER -p$SLAVE_PASS"
else
    SLAVE_CMD="mysql -h$SLAVE_HOST -P$SLAVE_PORT -u$SLAVE_USER"
fi

if [[ -n "$MASTER_PASS" ]]; then
    MASTER_CMD="mysql -h$MASTER_HOST -P$MASTER_PORT -u$MASTER_USER -p$MASTER_PASS"
else
    MASTER_CMD="mysql -h$MASTER_HOST -P$MASTER_PORT -u$MASTER_USER"
fi

# 查看状态模式
if [[ "$SHOW_STATUS" = true ]]; then
    echo "从库状态 ($SLAVE_HOST:$SLAVE_PORT):"
    $SLAVE_CMD -e "SHOW SLAVE STATUS\G"
    exit 0
fi

# 参数校验
[[ -z "$MASTER_HOST" || -z "$MASTER_USER" ]] && { echo "错误: 缺少主库参数！"; show_usage; exit 1; }
[[ -n "$BACKUP_FILE" && ! -f "$BACKUP_FILE" ]] && { echo "错误: 备份文件不存在"; exit 1; }
[[ -z "$BACKUP_FILE" && (-z "$MASTER_LOG_FILE" || -z "$MASTER_LOG_POS") ]] && { echo "错误: 需要备份文件或binlog位置"; exit 1; }

log "========== 开始配置主从复制 =========="

# 测试连接 - 添加详细错误信息
log "测试从库连接..."
if ! $SLAVE_CMD -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✗ 从库连接失败"
    echo "连接参数: $SLAVE_HOST:$SLAVE_PORT 用户:$SLAVE_USER"
    $SLAVE_CMD -e "SELECT 1;" 2>&1 | head -3
    exit 1
fi

log "测试主库连接..."
if ! $MASTER_CMD -e "SELECT 1;" >/dev/null 2>&1; then
    echo "✗ 主库连接失败"
    echo "连接参数: $MASTER_HOST:$MASTER_PORT 用户:$MASTER_USER"
    $MASTER_CMD -e "SELECT 1;" 2>&1 | head -3
    exit 1
fi

# 配置server-id
NEW_SERVER_ID=$(generate_server_id)
if update_server_id "$CONFIG_FILE" "$NEW_SERVER_ID"; then
    restart_mysql || { echo "⚠ 请手动重启MySQL"; exit 1; }
fi

# 获取binlog位置
if [[ -n "$BACKUP_FILE" ]]; then
    log "从备份文件提取binlog位置..."
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        BINLOG_LINE=$(gunzip -c "$BACKUP_FILE" | head -50 | grep -E "CHANGE MASTER TO.*MASTER_LOG_FILE.*MASTER_LOG_POS" | head -1)
    else
        BINLOG_LINE=$(head -50 "$BACKUP_FILE" | grep -E "CHANGE MASTER TO.*MASTER_LOG_FILE.*MASTER_LOG_POS" | head -1)
    fi

    [[ -z "$BINLOG_LINE" ]] && { echo "✗ 备份文件中未找到binlog位置"; exit 1; }

    MASTER_LOG_FILE=$(echo "$BINLOG_LINE" | grep -o "MASTER_LOG_FILE='[^']*'" | cut -d"'" -f2)
    MASTER_LOG_POS=$(echo "$BINLOG_LINE" | grep -o "MASTER_LOG_POS=[0-9]*" | cut -d"=" -f2)
    log "binlog位置: $MASTER_LOG_FILE:$MASTER_LOG_POS"
fi

# 配置主从复制
log "配置主从复制..."
$SLAVE_CMD -e "STOP SLAVE; RESET SLAVE ALL;" 2>>"$LOG_FILE"

$SLAVE_CMD -e "CHANGE MASTER TO MASTER_HOST='$MASTER_HOST', MASTER_PORT=$MASTER_PORT, MASTER_USER='$MASTER_USER', MASTER_PASSWORD='$MASTER_PASS', MASTER_LOG_FILE='$MASTER_LOG_FILE', MASTER_LOG_POS=$MASTER_LOG_POS;" 2>>"$LOG_FILE" || { echo "✗ 主从配置失败"; exit 1; }

$SLAVE_CMD -e "START SLAVE;" 2>>"$LOG_FILE" || { echo "✗ 启动复制失败"; exit 1; }

# 检查状态
sleep 3
SLAVE_STATUS=$($SLAVE_CMD -e "SHOW SLAVE STATUS\G" 2>/dev/null)
if [[ -n "$SLAVE_STATUS" ]]; then
    SLAVE_IO=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')
    SLAVE_SQL=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')

    if [[ "$SLAVE_IO" == "Yes" && "$SLAVE_SQL" == "Yes" ]]; then
        echo "✓ 主从复制配置成功！"
        echo "  主库: $MASTER_HOST:$MASTER_PORT"
        echo "  从库: $SLAVE_HOST:$SLAVE_PORT (server-id: $NEW_SERVER_ID)"
    else
        echo "⚠ 从库状态异常: IO=$SLAVE_IO, SQL=$SLAVE_SQL"
    fi
else
    echo "⚠ 无法获取从库状态"
fi

log "========== 配置完成 =========="
echo "日志文件: $LOG_FILE"
