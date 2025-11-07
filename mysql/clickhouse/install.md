1、安装python3 虚拟环境
bash /debian/system/py3.sh
 
2、安装psutil clickhouse_connect

/opt/py3/bin/pip3 install psutil clickhouse_connect

3、示例

# 使用主从模式配置启动

python3 sync_mysql_clickhouse.py --config config_master_slave.json

# 使用单库模式配置启动

python3 sync_mysql_clickhouse.py --config config_single.json

# 重置并全量同步

python3 sync_mysql_clickhouse.py --config config_single.json --reset --force

# 启动支持 MySQL 端口的 ClickHouse 容器

docker run -d \
--name clickhouse-server \
-p 8123:8123 \
-p 9000:9000 \
-p 9004:9004 \
-e CLICKHOUSE_PASSWORD=Hm8899 \
--ulimit nofile=262144:262144 \
clickhouse/clickhouse-server

# 等待启动
sleep 10

# 配置查询缓存
docker exec ch1 clickhouse-client --query "
SET use_query_cache = 1;
SET enable_writes_to_query_cache = 1;
SET enable_reads_from_query_cache = 1;
SET query_cache_ttl = 3600;
SELECT 'Query cache enabled' as result;
"

# 从 MySQL 迁移数据到 ClickHouse
