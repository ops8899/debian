#!/bin/bash

# 设置为非交互模式，避免安装过程中需要用户输入
export DEBIAN_FRONTEND=noninteractive

# 定义项目数组
projects=("gate" "op")

# 获取当前脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 使用循环构建项目
for project in "${projects[@]}"; do
    cd "$script_dir/$project" && bash build.sh
done

# 如果有参数，则推送镜像
if [ -n "$1" ]; then
    for project in "${projects[@]}"; do
        docker push "ops8899/$project"
    done
fi
