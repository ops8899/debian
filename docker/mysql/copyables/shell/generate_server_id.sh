#!/bin/bash

# 检查是否已经存在 server-id 配置文件
SERVER_ID_FILE="/var/lib/mysql/server-id.cnf"

# 如果文件不存在，生成一个新的随机 server-id (1-4294967295)
# 使用容器 IP 地址的最后一段作为基础，确保在同一网络中唯一
IP_LAST_OCTET=$(hostname -i | awk -F. '{print $4}')

# 生成一个随机数并与 IP 地址结合，确保唯一性
RANDOM_PART=$((RANDOM % 10000 + 1))
SERVER_ID=$((1000000 + IP_LAST_OCTET * 10000 + RANDOM_PART))

# 确保 server-id 在有效范围内
if [ "$SERVER_ID" -gt 4294967295 ]; then
    SERVER_ID=$((SERVER_ID % 4294967295))
    # 确保 server-id 不为 0
    if [ "$SERVER_ID" -eq 0 ]; then
        SERVER_ID=1
    fi
fi

# 将 server-id 保存到文件中，以备重启后使用
echo "$SERVER_ID" > "$SERVER_ID_FILE"
echo "生成了新的 server-id: $SERVER_ID"

# 创建 server-id 配置文件
echo "[mysqld]" > /etc/mysql/conf.d/server-id.cnf
echo "server-id = $SERVER_ID" >> /etc/mysql/conf.d/server-id.cnf

# 输出 MySQL 配置信息

echo "MySQL 将使用 server-id = $SERVER_ID 启动"
