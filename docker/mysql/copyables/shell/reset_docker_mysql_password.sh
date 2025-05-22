#!/bin/bash

generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

MYSQL_PASSWORD=$(generate_password)

# 如果有传参就直接使用第1个参数作为容器名称，否则提示用户输入
if [ $# -ge 1 ]; then
    CONTAINER_NAME=$1
else
  # 提示用户输入容器名称
  read -p "请输入 要恢复 ROOT 密码 的MySQL 容器名称（默认: mysql1）: " CONTAINER_NAME
  CONTAINER_NAME=${CONTAINER_NAME:-mysql1} # 使用用户输入的值，或默认值 mysql1
fi

# 如果有传参就直接使用第1个参数作为容器名称，否则提示用户输入
if [ $# -ge 2 ]; then
    NEW_PASSWORD=$2
else
  # 提示用户输入新密码
  read -p "请输入 root 用户的新密码（默认: $MYSQL_PASSWORD）: " NEW_PASSWORD
  NEW_PASSWORD=${NEW_PASSWORD:-$MYSQL_PASSWORD} # 使用用户输入的值，或默认值 $MYSQL_PASSWORD
fi

# 定义其他必要变量
HOST_CONF_PATH="/root/.mysql" # 宿主机保存配置文件的路径
MYSQL_CONF_PATH="/etc/mysql/conf.d/docker.cnf" # 容器内配置文件路径

# 创建宿主机配置目录
mkdir -p "${HOST_CONF_PATH}"

echo "1. 复制 MySQL 容器中的配置文件到宿主机..."
docker cp "${CONTAINER_NAME}:${MYSQL_CONF_PATH}" "${HOST_CONF_PATH}/"
if [ $? -ne 0 ]; then
    echo "错误：无法复制配置文件，请检查容器名称和路径！"
    exit 1
fi

echo "2. 备份并修改配置文件..."
cp "${HOST_CONF_PATH}/docker.cnf" "${HOST_CONF_PATH}/docker.cnf.backup"
echo "skip-grant-tables" >> "${HOST_CONF_PATH}/docker.cnf"

echo "3. 将修改后的配置文件上传回容器..."
docker cp "${HOST_CONF_PATH}/docker.cnf" "${CONTAINER_NAME}:${MYSQL_CONF_PATH}"

echo "4. 重启 MySQL 容器..."
docker restart "${CONTAINER_NAME}"
sleep 5

echo "5. 进入容器并重置 root 密码..."
docker exec -i "${CONTAINER_NAME}" mysql -u root <<EOF
USE mysql;
UPDATE mysql.user SET authentication_string='' WHERE user='root';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE user='root';
FLUSH PRIVILEGES;

ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
FLUSH PRIVILEGES;

-- 重置 cc@localhost 用户 (如果存在)
CREATE USER IF NOT EXISTS 'cc'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
ALTER USER 'cc'@'localhost' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'cc'@'localhost' WITH GRANT OPTION;

-- 重置 cc@% 用户 (如果存在)
CREATE USER IF NOT EXISTS 'cc'@'%' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
ALTER USER 'cc'@'%' IDENTIFIED WITH mysql_native_password BY '${NEW_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'cc'@'%' WITH GRANT OPTION;

-- 最后刷新权限
FLUSH PRIVILEGES;
EOF

echo "6. 恢复原始配置文件..."
docker cp "${HOST_CONF_PATH}/docker.cnf.backup" "${CONTAINER_NAME}:${MYSQL_CONF_PATH}"

echo "7. 重启 MySQL 容器..."
docker restart "${CONTAINER_NAME}"

echo "操作完成！root 用户的新密码为：${NEW_PASSWORD}"

# 生成配置
docker exec "${CONTAINER_NAME}" bash -c "export MYSQL_ROOT_PASSWORD=${NEW_PASSWORD} && /shell/generate_root_conf.sh && /shell/generate_client_conf.sh"