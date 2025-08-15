# 全库备份数据库

# mysql root 密码
source /etc/mysql.conf
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_IP="127.0.0.1"
MYSQL_PORT="61786"

# 是否压缩,不压缩注释下一行
COMPRESS_CMD=" --compress --compress-threads=16 --slave-info "

# mysql 的数据目录
SAVE_PATH="/data/mysql"

# 备份目录
BACKUP_DIR="/data/backup/db/full/"
mkdir -p $BACKUP_DIR

# 生成目标备份目录
TARGET_DIR="${BACKUP_DIR}/$(date +%Y-%m-%d-%H-%M-%S)"

# 执行 xtrabackup 备份
xtrabackup --defaults-file=/etc/my.cnf ${COMPRESS_CMD} --datadir=${SAVE_PATH} --host="${MYSQL_IP}" --user='root' --password="${MYSQL_PASSWORD}" --port=${MYSQL_PORT} --backup --target-dir="${TARGET_DIR}"

# 将 mysql.conf 拷贝到备份目录
cp /etc/mysql.conf "${TARGET_DIR}/mysql.conf"
