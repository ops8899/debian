#!/bin/bash

# 密码配置文件路径
CONFIG_FILE="/etc/mysql/root.conf"

# 输出配置内容到文件
echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" > $CONFIG_FILE