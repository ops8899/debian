#!/bin/bash

# 日志目录
LOG_DIR="/root/log"

# 保留的行数
MAX_LINES=1000

# 遍历目录下的所有 .log 文件
for log_file in "$LOG_DIR"/*.log; do
  # 检查文件是否存在
  if [ -f "$log_file" ]; then
    # 获取文件的行数
    line_count=$(wc -l < "$log_file")

    # 如果文件行数大于 MAX_LINES，才进行处理
    if [ "$line_count" -gt "$MAX_LINES" ]; then
      # 使用 tail 提取最新的 MAX_LINES 行到临时文件
      tail -n $MAX_LINES "$log_file" > "${log_file}.tmp"

      # 使用 cat 将临时文件内容覆盖到原文件
      cat "${log_file}.tmp" > "$log_file"

      # 删除临时文件
      rm -f "${log_file}.tmp"

      echo "Processed: $log_file (Original lines: $line_count)"
    else
      echo "Skipped: $log_file (Lines: $line_count, less than or equal to $MAX_LINES)"
    fi
  fi
done