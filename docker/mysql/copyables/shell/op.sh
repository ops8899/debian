#!/bin/bash
# MySQL 参数优化脚本

# 获取总内存（单位 KB）
TOTAL_MEMORY=$(awk '/MemTotal/ {print $2}' /proc/meminfo)

# 确保 TOTAL_MEMORY 是有效数字
if [[ ! "$TOTAL_MEMORY" =~ ^[0-9]+$ ]]; then
    echo "无法获取总内存大小，请检查 /proc/meminfo 文件。"
    exit 1
fi

# 计算一半内存大小（单位 MB），且为 512M 的倍数
HALF_MEMORY_VALUE=$((TOTAL_MEMORY / 2 / 1024 / 512 * 512))

# 如果计算结果小于 512M，则设置为 512M
if [[ "$HALF_MEMORY_VALUE" -lt 512 ]]; then
    HALF_MEMORY_VALUE=512
fi

# 设置带单位的内存值（如果大于等于1024MB则转换为GB）
if [ $HALF_MEMORY_VALUE -ge 1024 ]; then
    HALF_MEMORY="$((HALF_MEMORY_VALUE / 1024))G"
else
    HALF_MEMORY="${HALF_MEMORY_VALUE}M"
fi

echo "总内存大小：$TOTAL_MEMORY KB"
echo "分配给MySQL的内存：$HALF_MEMORY"

# 动态调整 innodb_read_io_threads 和 innodb_write_io_threads
CPU_THREADS=$(grep -c ^processor /proc/cpuinfo) # 获取 CPU 线程数
HALF_THREADS=$((CPU_THREADS / 2))
if [ $HALF_THREADS -lt 2 ]; then
    HALF_THREADS=2
fi

# 创建配置目录（如果不存在）
mkdir -p /etc/mysql/conf.d

# 生成新的MySQL配置文件
CONFIG_FILE="/etc/mysql/conf.d/optimized.cnf"
echo "生成新的MySQL配置文件: $CONFIG_FILE"

cat > $CONFIG_FILE << EOF
[mysqld]
# 性能优化参数
innodb_buffer_pool_size = $HALF_MEMORY
innodb_read_io_threads = $HALF_THREADS
innodb_write_io_threads = $HALF_THREADS
EOF

# 设置适当的权限
chmod 644 $CONFIG_FILE

echo "MySQL 配置文件已生成！"
echo "配置参数摘要："
echo "innodb_buffer_pool_size: $HALF_MEMORY"
echo "innodb_read_io_threads: $HALF_THREADS"
echo "innodb_write_io_threads: $HALF_THREADS"
echo ""
echo "请重启 MySQL 服务以应用新配置。"
