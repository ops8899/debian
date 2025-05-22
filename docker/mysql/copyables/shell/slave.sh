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

# 确保必需的变量已设置
if [ -z "$MASTER_REPLICATION_USER" ] || [ -z "$MASTER_REPLICATION_PASSWORD" ]; then
    echo "复制用户或密码未设置，请检查 $CONFIG_FILE_ROOT。"
    exit 1
fi

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
bash /shell/master_backup.sh
source /etc/mysql/master_backup.conf

# 3. 恢复数据
bash /shell/slave_import.sh

# 4. 配置主从复制
bash /shell/slave_config.sh

echo ""
echo "===== 从机配置完成 ====="
echo ""
echo ""
echo "===== 请立即重启 MySQL 服务 ====="
echo ""
