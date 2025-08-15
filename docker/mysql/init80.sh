#!/bin/bash

echo "配置 MySQL 80 环境"
echo "参数个数: $#"
echo "第一个参数: $1"

# 如果有传参就直接使用第1个参数作为容器名称，否则提示用户输入
if [ $# -ge 1 ]; then
    container=$1
else
    read -p "容器名称 [默认：mysql80]: " container
    container=${container:-mysql80}
fi

echo "正在配置容器: $container"

# 复制配置文件和脚本到容器
docker cp copyables/conf $container:/
docker cp copyables/shell $container:/

# 在容器内执行配置操作
docker exec $container bash -c "cp /conf/mysql80.cnf /etc/mysql/conf.d/mysql.cnf"
docker exec $container bash -c "chmod +x /shell/*.sh"
docker exec $container bash -c "/shell/setup.sh"

# 重启容器,让配置生效
docker restart $container
sleep 5
docker exec $container bash -c "mysql -e 'show master status\G;'"

echo "MySQL 8.0.42 环境配置完成"
