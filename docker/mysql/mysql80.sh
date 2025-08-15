#!/bin/bash

#  第一步

# 使用MySQL 8.0.30 debian镜像
image_name="mysql:8.0.42-debian"

# 删除旧的容器（如果存在）
docker stop mysql80 -t 1
echo "y" | docker rm -f mysql80

# 运行新容器
docker run --privileged -d \
  --name mysql80 \
  --restart=always \
  -e MYSQL_ROOT_PASSWORD=Test8899 \
  -p 3380:3306 \
  $image_name

docker logs -f mysql80 &

sleep 20

# 等待显示 "mysqld: ready for connections."
# 第一步完成

#  第二步
# 初始化MYSQL环境
bash init80.sh mysql80

#  第三步
# 参数优化
docker exec mysql80 bash -c "/shell/op.sh"

cat <<EOF

# 第四步
# 重置密码
docker cp mysql80:/shell/reset_docker_mysql_password.sh .
bash reset_docker_mysql_password.sh

# 显示密码信息
docker exec mysql80 bash -c "/shell/info.sh"

# 第五步
# 建立从库方法

SLAVE_HOST="x" # 从库主机地址
SLAVE_PORT="28847" # 从库端口
ROOT_USER="root" # 主库根用户
ROOT_PASSWORD="x"
REPL_USER="repl" # 从库同步用户
REPL_PASSWORD="x"
DB_NAME="xhs" # 同步数据库名称

docker exec mysql80 bash -c "/shell/slave.sh $SLAVE_HOST $SLAVE_PORT $ROOT_USER $ROOT_PASSWORD $REPL_USER $REPL_PASSWORD $DB_NAME"

# 第六步
# 删除备份主库的数据
docker exec mysql80 bash -c "rm -f /backup/*"

# 重启
docker restart mysql80
# 检查主库状态
docker exec mysql80 bash -c "mysql -e 'show master status\G;'"
# 检查从库状态
docker exec mysql80 bash -c "mysql -e 'show slave status\G;'"

EOF