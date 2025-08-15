#!/bin/bash

# 配置文件路径
CONFIG_FILE_ROOT="/etc/mysql/root.conf"
CONFIG_FILE_REPL="/etc/mysql/repl.conf"
MASTER_CONFIG_FILE="/etc/mysql/master.conf"

echo "-----------------"
echo ""
if [ -f "$CONFIG_FILE_ROOT" ]; then
  echo "配置文件内容:"
  cat "$CONFIG_FILE_ROOT"
else
  echo "错误: 配置文件 $CONFIG_FILE_ROOT 不存在!"
fi

echo "-----------------"
echo ""
echo "-----------------"
echo ""
if [ -f "$CONFIG_FILE_REPL" ]; then
  echo "配置文件内容:"
  cat "$CONFIG_FILE_REPL"
else
  echo "错误: 配置文件 $CONFIG_FILE_REPL 不存在!"
fi

echo "-----------------"
echo ""

if [ -f "$MASTER_CONFIG_FILE" ]; then
  echo "master配置文件内容:"
  cat "$MASTER_CONFIG_FILE"
else
  echo "错误: master配置文件 $MASTER_CONFIG_FILE 不存在!"
fi
echo ""