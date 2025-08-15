#!/bin/bash
# MySQL 用户密码重新生成脚本
# 为已存在的 root、cc 和 repl 用户生成新的随机密码

# 配置文件路径
CONFIG_FILE="/etc/mysql/root.conf"

# 随机生成密码函数
generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

echo "开始重新生成 MySQL 用户密码..."

# 生成新的随机密码
NEW_ROOT_PASSWORD=$(generate_password)
MYSQL_REPLICATION_USER="repl"
NEW_REPLICATION_PASSWORD=$(generate_password)

echo "新密码已生成"

# 更新 MySQL 用户密码
echo "更新 MySQL 用户密码..."
mysql <<EOF
-- 更新 root@localhost 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_ROOT_PASSWORD}';

-- 更新 cc@'%' 用户密码
ALTER USER 'cc'@'%' IDENTIFIED BY '${NEW_ROOT_PASSWORD}';

-- 更新复制用户密码
ALTER USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${NEW_REPLICATION_PASSWORD}';

FLUSH PRIVILEGES;
EOF

# 检查上一个命令的执行结果
if [ $? -ne 0 ]; then
    echo "错误: MySQL 用户密码更新失败!"
    exit 1
fi

# 保存新密码到配置文件
cat > "$CONFIG_FILE" <<EOF
MYSQL_ROOT_PASSWORD=$NEW_ROOT_PASSWORD
MYSQL_REPLICATION_USER=$MYSQL_REPLICATION_USER
MYSQL_REPLICATION_PASSWORD=$NEW_REPLICATION_PASSWORD
EOF

# 设置配置文件权限
chmod 600 "$CONFIG_FILE"

echo "密码已更新并保存到 $CONFIG_FILE"
echo "root 和 cc 用户新密码: $NEW_ROOT_PASSWORD"
echo "复制用户 $MYSQL_REPLICATION_USER 新密码: $NEW_REPLICATION_PASSWORD"

# 生成 MySQL 客户端配置
if [ -f "/shell/generate_client_conf.sh" ]; then
    echo "更新 MySQL 客户端配置..."
    bash /shell/generate_client_conf.sh
fi

echo "MySQL 用户密码重置完成!"
