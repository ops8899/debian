#!/bin/bash
# 不交互
export DEBIAN_FRONTEND=noninteractive

# 更新并安装必要的工具
apt-get update --allow-insecure-repositories && apt-get install -y --allow-unauthenticated \
    bash \
    iputils-ping \
    net-tools \
    procps \
    vim \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 随机生成密码函数
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

# 生成id
bash /shell/generate_server_id.sh

# 生成 root 用户配置
bash /shell/generate_root_conf.sh

# 创建 cc@'%' 用户
echo "创建 cc 用户并授予远程访问权限..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
-- 选择 mysql 数据库
USE mysql;
-- 创建一个临时表（DDL 操作会触发 GTID）
CREATE TEMPORARY TABLE temp_table (id INT);
DROP TEMPORARY TABLE temp_table;

CREATE USER IF NOT EXISTS 'cc'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'cc'@'localhost' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS 'cc'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'cc'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EOF

echo "禁用 root 用户..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOF
ALTER USER 'root'@'localhost' ACCOUNT LOCK;
ALTER USER 'root'@'%' ACCOUNT LOCK;
FLUSH PRIVILEGES;
EOF

# 生成 MySQL 客户端配置
bash /shell/generate_client_conf.sh

# 配置文件路径
CONFIG_FILE_REPL="/etc/mysql/repl.conf"

# 随机生成 root 密码和 replication 用户名、密码
MYSQL_REPLICATION_USER="repl"
MYSQL_REPLICATION_PASSWORD=$(generate_password)

cat > "$CONFIG_FILE_REPL" <<EOF
MYSQL_REPLICATION_USER=$MYSQL_REPLICATION_USER
MYSQL_REPLICATION_PASSWORD=$MYSQL_REPLICATION_PASSWORD
EOF

chmod 600 "$CONFIG_FILE_REPL"
echo "密码已保存到 $CONFIG_FILE_REPL"


# 创建 replication 用户
echo "创建复制用户: $MYSQL_REPLICATION_USER"
mysql <<EOF
-- 创建 replication 用户（如果不存在）
CREATE USER IF NOT EXISTS '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';
-- 授予权限
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "MySQL 配置已完成！"
echo "root 密码和 replication 用户名、密码已保存到 /etc/mysql/root.conf /etc/mysql/repl.conf"

echo "MySQL Master 状态:"
mysql <<EOF
show master status\G;
EOF

sleep 3