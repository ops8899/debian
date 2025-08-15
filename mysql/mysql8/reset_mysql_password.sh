#!/bin/bash

# 随机生成密码函数
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()-_=+<>?' </dev/urandom | head -c 12
}

# 生成随机密码并赋值给系统变量 MYSQL_ROOT_PASSWORD
export MYSQL_ROOT_PASSWORD=$(generate_password)

echo "生成的新密码为：${MYSQL_ROOT_PASSWORD}"

# 停止 MySQL 服务
echo "停止 MySQL 服务..."
pkill mysqld

# 启动 MySQL 安全模式
echo "启动 MySQL 安全模式..."
mysqld_safe --skip-grant-tables --skip-networking &
sleep 5

# 重置 root 密码
echo "重置 root 用户密码..."
mysql -u root << EOF
USE mysql;
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EXIT;
EOF

# 停止 MySQL 安全模式
echo "停止 MySQL 安全模式..."
pkill mysqld
sleep 2

# 重新启动 MySQL 服务
echo "重新启动 MySQL 服务..."
mysqld_safe &

# 输出新密码
echo "root 用户的新密码为：${MYSQL_ROOT_PASSWORD}"

bash /shell/generate_client_conf.sh
