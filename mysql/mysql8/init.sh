#!/bin/bash

# 停止 MySQL 服务
/etc/init.d/mysqld stop

# 备份配置文件
cp /etc/my.cnf /etc/my.cnf.bak

# 修改配置文件（假设 my.cnf 在当前目录）
cp my.cnf /etc/my.cnf

# 检查数据目录
if [ -d /www/server/mysql ]; then
  count=$(ls -1 /www/server/mysql | wc -l)
  if [ $count -gt 0 ]; then
    mv /www/server/mysql /www/server/mysql_$(date +%Y-%m-%d-%H-%M-%S)
  fi
else
  mkdir -p /www/server/mysql
fi

# 初始化 MySQL
/www/server/mysql/bin/mysqld --initialize-insecure --user=mysql --basedir=/www/server/mysql --datadir=/www/server/mysql

systemctl enable mysql

# 启动 MySQL 服务
/etc/init.d/mysqld start

# 生成随机密码
MYSQL_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
SLAVE_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)

# 保存密码到 /etc/mysql.conf
echo "MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}" > /etc/mysql.conf
echo "MYSQL_SLAVE_PASSWORD=${SLAVE_PASSWORD}" >> /etc/mysql.conf

# 设置初始密码（使用空密码连接）
#echo "$MYSQL_PASSWORD" | /www/server/mysql/bin/mysqladmin -u root password "$MYSQL_PASSWORD" --skip-password
echo "$MYSQL_PASSWORD" | bt 7

sleep 3

# 检查 MySQL 连接
if ! /www/server/mysql/bin/mysql -uroot -p"$MYSQL_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
  echo "MySQL 登录失败，请检查配置和密码设置。"
  exit 1
fi

# 添加同步用户名
PRIV_SQL="CREATE USER 'slave_sync'@'%' IDENTIFIED BY '${SLAVE_PASSWORD}'; GRANT REPLICATION SLAVE ON *.* TO 'slave_sync'@'%'; FLUSH PRIVILEGES;"
/www/server/mysql/bin/mysql -uroot -p"$MYSQL_PASSWORD" -e "$PRIV_SQL"

# 创建 root 用户
PRIV_SQL="CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
/www/server/mysql/bin/mysql -uroot -p"$MYSQL_PASSWORD" -e "$PRIV_SQL"

# 检查主状态
/www/server/mysql/bin/mysql -uroot -p"$MYSQL_PASSWORD" -e 'SHOW MASTER STATUS'

sed -i 's|#PASSWORD#|'"$MYSQL_PASSWORD"'|g' /etc/my.cnf

# 显示网络状态
netstat -ntlp
