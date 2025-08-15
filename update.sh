#!/bin/bash

# 备份本地修改
git stash
git pull
git stash pop  # 尝试合并修改


echo "更新完成！"
