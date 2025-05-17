#!/bin/bash
image_name="mysql:5.7-debian"  # 使用MySQL 5.7 debian镜像

# 删除旧的容器（如果存在）
docker stop mysql1 -t 1
echo "y" | docker rm -f mysql1

# 运行新容器
docker run --privileged -d \
  --name mysql1 \
  --restart=always \
  -e MYSQL_ROOT_PASSWORD=Test8899 \
  -p 3307:3306 \
  $image_name

docker logs -f mysql1




cd /debian/docker/mysql && bash init5.7.sh

# 参数优化
docker exec mysql1 bash -c "/shell/op.sh"

# 重置密码
docker cp mysql1:/shell/reset_docker_mysql_password.sh .
bash reset_docker_mysql_password.sh

# 显示密码信息
docker exec mysql1 bash -c "/shell/info.sh"

# 建立从库
SLAVE_HOST="x" # 从库主机地址
SLAVE_PORT="28847" # 从库端口
ROOT_USER="root" # 主库根用户
ROOT_PASSWORD="x"
REPL_USER="repl" # 从库同步用户
REPL_PASSWORD="x"
DB_NAME="xhs" # 同步数据库名称

docker exec mysql8 bash -c "/shell/setup_slave.sh $SLAVE_HOST $SLAVE_PORT $ROOT_USER $ROOT_PASSWORD $REPL_USER $
REPL_PASSWORD $DB_NAME"
