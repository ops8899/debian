#!/bin/bash

echo "配置mysql5.7环境"

read -p "容器名称 [默认：mysql1]: " container
container=${container:-mysql1}

docker cp copyables/conf $container:/
docker cp copyables/shell $container:/

docker exec $container bash -c "cp /conf/mysql5.7.cnf /etc/mysql/conf.d/mysql.cnf"
docker exec $container bash -c "chmod +x /shell/*.sh"
docker exec $container bash -c "/shell/setup.sh"
