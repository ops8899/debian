#!/bin/bash

# 默认版本号为v1，如果提供了第一个参数，则使用该参数作为版本号
version="v1"
if [ -n "$1" ]; then
  # 检查参数是否只包含数字，如果是则添加v前缀
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    version="v$1"
  else
    version="$1"
  fi
fi

# 设置镜像名称
container_name="mysql57"
image_name="ops8899/$container_name:$version"

echo "正在提交容器 $container_name 为镜像 $image_name"

# 提交容器为镜像
if docker commit $container_name $image_name; then
  echo "镜像 $image_name 创建成功"

  # 如果提供了第二个参数且为push，则推送镜像
  if [ -n "$2" ] && [ "$2" = "push" ]; then
    echo "正在推送镜像 $image_name 到仓库..."
    if docker push $image_name; then
      echo "镜像 $image_name 推送成功"
    else
      echo "错误：镜像推送失败"
      exit 1
    fi
  else
    echo "提示：如需推送镜像，请添加第二个参数 'push'，例如：$0 $version push"
  fi
else
  echo "错误：镜像创建失败"
  exit 1
fi
