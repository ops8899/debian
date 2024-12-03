# 删除旧的容器（如果存在）
echo "y" | docker rm -f tweb

# 运行新容器
docker run --privileged -itd --network host \
  --name tweb \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --cgroupns=host \
  ops8899/web