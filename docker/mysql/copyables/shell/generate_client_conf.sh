#!/bin/bash

# 密码配置文件路径
CONFIG_FILE="/etc/mysql/root.conf"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件 $CONFIG_FILE 不存在，请先创建配置文件。"
    exit 1
fi

# 从配置文件中读取变量
source "$CONFIG_FILE"


# 客户端配置文件路径
CLIENT_CONFIG_FILE="/etc/mysql/conf.d/client.cnf"

# 确保目录存在
mkdir -p /etc/mysql/conf.d

# 输出配置内容到文件
cat > "$CLIENT_CONFIG_FILE" <<EOF
[client]
user=cc
password=$MYSQL_ROOT_PASSWORD

[mysqldump]
user=cc
password = $MYSQL_ROOT_PASSWORD
quick
max_allowed_packet = 64M
EOF

# 确保配置文件权限安全
chmod 600 "$CLIENT_CONFIG_FILE"

# 输出完成信息
echo "MySQL 客户端配置已保存到 $CLIENT_CONFIG_FILE"
cat /etc/mysql/conf.d/client.cnf