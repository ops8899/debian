#!/bin/bash
image_name="mysql:5.7-debian"  # 使用MySQL 5.7 debian镜像

# 删除旧的容器（如果存在）
docker stop mysql1 -t 1
echo "y" | docker rm -f mysql1

# 运行新容器
docker run --privileged -d \
  --name mysql1 \
  --restart=always \
  -p 3307:3306 \
  $image_name

docker logs -f mysql1
