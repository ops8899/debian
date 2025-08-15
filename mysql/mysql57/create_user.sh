#!/bin/bash

CONFIG_FILE="/etc/mysql.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    read -sp "请输入MySQL密码: " MYSQL_ROOT_PASSWORD
    echo
    echo "MYSQL_ROOT_PASSWORD=\"$MYSQL_ROOT_PASSWORD\"" > "$CONFIG_FILE"
fi

SLAVE_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
echo "MYSQL_SLAVE_PASSWORD=${SLAVE_PASSWORD}" >> /etc/mysql.conf

PRIV_SQL="
DELETE FROM mysql.user WHERE User='slave_sync' AND Host='%';
CREATE USER 'slave_sync'@'%' IDENTIFIED BY '${SLAVE_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO 'slave_sync'@'%';
FLUSH PRIVILEGES;

DELETE FROM mysql.user WHERE User='root' AND Host='%';
CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"
/www/server/mysql/bin/mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$PRIV_SQL"
