#!/bin/bash

container_name="web"
image_name="ops8899/kaixin:80"

# 删除旧的容器（如果存在）
docker stop $container_name -t 1
echo "y" | docker rm -f $container_name

# 运行新容器
docker run --privileged -itd \
  --network=host \
  -v /data:/data \
  --name $container_name \
  --restart=always \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v /etc/hosts:/etc/hosts \
  -v /etc/resolv.conf:/etc/resolv.conf \
  --log-driver=json-file --log-opt max-size=20m --log-opt max-file=5 \
  --cgroupns=host \
  $image_name
