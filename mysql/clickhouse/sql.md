# 实际用到的SQL语句示例：

1. 创建MySQL引擎数据库

CREATE DATABASE IF NOT EXISTS mysql_db
ENGINE = MySQL('localhost:3306', 'test', 'root', 'password');

CREATE DATABASE IF NOT EXISTS mysql_slave_db
ENGINE = MySQL('localhost:3307', 'test', 'root', 'password');


2. 检查表是否存在

EXISTS TABLE test_table


3. 创建ReplacingMergeTree表

CREATE TABLE test_table
ENGINE = ReplacingMergeTree(update_time)
ORDER BY id
AS SELECT * FROM mysql_db.test_table LIMIT 0;


4. 查看表结构

DESCRIBE test_table


5. 修改DateTime字段为DateTime64(3)

ALTER TABLE test_table MODIFY COLUMN update_time DateTime64(3);
ALTER TABLE test_table MODIFY COLUMN create_time DateTime64(3);


6. 全量数据初始化

INSERT INTO test_table SELECT * FROM mysql_db.test_table;
-- 或使用从库
INSERT INTO test_table SELECT * FROM mysql_slave_db.test_table;


7. 获取记录数

SELECT COUNT(*) FROM test_table


8. 获取最大时间戳（增量同步用）

SELECT MAX(update_time) FROM test_table FINAL;


9. 增量同步数据

-- 检查是否有新数据
SELECT COUNT(*) FROM mysql_db.test_table
WHERE update_time > '2023-01-01 12:00:00'
LIMIT 1;

-- 插入新数据
INSERT INTO test_table
SELECT * FROM mysql_db.test_table
WHERE update_time > '2023-01-01 12:00:00';


10. 补数据操作

-- 从MySQL获取时间窗口内的ID
SELECT id FROM mysql_db.test_table
WHERE update_time BETWEEN '2023-01-01 12:00:00' AND '2023-01-01 12:05:00';

-- 从ClickHouse获取时间窗口内的ID
SELECT id FROM test_table FINAL
WHERE update_time BETWEEN '2023-01-01 12:00:00' AND '2023-01-01 12:05:00';

-- 插入缺失数据（通过ID列表）
INSERT INTO test_table
SELECT * FROM mysql_db.test_table
WHERE id IN (1001, 1002, 1003);


11. 删除表（重置用）

DROP TABLE IF EXISTS test_table;
DROP DATABASE IF EXISTS mysql_db;
DROP DATABASE IF EXISTS mysql_slave_db;


关键特性说明：

1. FINAL关键字：确保查询ReplacingMergeTree表的最新状态
2. 直接时间比较：update_time > '2023-01-01 12:00:00'（无函数转换）
3. MySQL引擎表：mysql_db.table_name直接访问映射的MySQL表
4. ReplacingMergeTree：按update_time自动去重，ORDER BY id确定主键

这些就是您代码中实际使用的所有SQL语句。