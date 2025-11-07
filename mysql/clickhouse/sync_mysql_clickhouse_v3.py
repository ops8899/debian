#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MySQL到ClickHouse高速同步工具 - 支持主从分离版 - 去除时间函数优化版"""

import argparse
import clickhouse_connect
import json
import logging
import os
import psutil
import signal
import sys
import time
from datetime import timezone, timedelta, datetime

# 配置
SYNC_INTERVAL = 0.5  # 增量同步间隔
BACKFILL_INTERVAL = 300  # 补数据间隔（5分钟）
BACKFILL_WINDOW = 300  # 补数据检查窗口（5分钟）
TIMEZONE_OFFSET = timezone(timedelta(hours=8))  # 东八区

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    stream=sys.stdout  # 强制输出到标准输出
)

def load_config(path):
    if not os.path.exists(path):
        config = {
            "clickhouse": {"host": "localhost", "port": 8123, "username": "default", "password": "",
                           "database": "test"},
            "mysql": {"host": "localhost", "port": 3306, "database": "test", "username": "root", "password": ""},
            "mysql_slave": {"host": "localhost", "port": 3307, "database": "test", "username": "root", "password": ""},
            "tables": {"test_table": {"id_field": "id", "time_field": "update_time"}}
        }
        with open(path, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"❌ 已创建配置文件: {path}")
        print("📝 配置说明:")
        print("  - mysql: 主库，用于增量同步和补数据")
        print("  - mysql_slave: 从库（可选），用于全量初始化，不配置则使用主库")
        sys.exit(1)

    with open(path) as f:
        return json.load(f)


def check_single_instance(config_path):
    """确保同一配置只运行一个实例"""
    config_abs = os.path.abspath(config_path)
    lock_file = f"{config_abs}.lock"
    current_pid = os.getpid()

    if os.path.exists(lock_file):
        with open(lock_file) as f:
            old_pid = int(f.read().strip())
        if psutil.pid_exists(old_pid) and old_pid != current_pid:
            print(f"❌ 配置文件: {config_path} 实例已运行 (PID: {old_pid}) \n🚫 禁用进程: kill -9 {old_pid}")
            sys.exit(1)

    with open(lock_file, 'w') as f:
        f.write(str(current_pid))

    logging.info(f"✅ 配置文件: {config_path} 实例启动成功 (PID: {current_pid})")
    return lock_file

def get_max_timestamp_optimized(client, table: str, time_field: str):
    """优化的获取最大时间戳 - 避免函数转换"""
    try:
        result = client.query(f"SELECT MAX({time_field}) FROM {table} FINAL").result_rows[0][0]
        if result is None:
            return datetime.fromtimestamp(0)  # 返回最小时间
        return result
    except:
        return datetime.fromtimestamp(0)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', default='config.json')
    parser.add_argument('--reset', action='store_true')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()

    # 单实例检查
    lock_file = check_single_instance(args.config)

    config = load_config(args.config)
    CH_CONFIG = config['clickhouse']
    MYSQL_CONFIG = config['mysql']
    MYSQL_SLAVE_CONFIG = config.get('mysql_slave')  # 可选从库配置
    TABLES = config['tables']

    stop_flag = False
    last_backfill_time = 0

    def get_client():
        return clickhouse_connect.get_client(**CH_CONFIG)

    def create_mysql_db(client, db_name, mysql_cfg, purpose=""):
        """创建MySQL数据库引擎"""
        mysql_url = f"{mysql_cfg['host']}:{mysql_cfg['port']}"
        client.command(
            f"CREATE DATABASE IF NOT EXISTS {db_name} ENGINE = MySQL('{mysql_url}', '{mysql_cfg['database']}', '{mysql_cfg['username']}', '{mysql_cfg['password']}')")
        if purpose:
            logging.info(f"🔗 {db_name}: 连接到 {mysql_cfg['host']}:{mysql_cfg['port']} ({purpose})")

    def init():
        client = get_client()

        if args.reset:
            if not args.force and input("确认重置？(yes): ") != 'yes':
                return False
            for table in TABLES:
                try:
                    client.command(f"DROP TABLE IF EXISTS {table}")
                except:
                    pass
            try:
                client.command("DROP DATABASE IF EXISTS mysql_db")
                client.command("DROP DATABASE IF EXISTS mysql_slave_db")
            except:
                pass

        # 创建主库连接
        create_mysql_db(client, "mysql_db", MYSQL_CONFIG, "主库")

        # 创建从库连接（如果配置了从库）
        init_db = "mysql_db"  # 默认使用主库初始化
        if MYSQL_SLAVE_CONFIG:
            create_mysql_db(client, "mysql_slave_db", MYSQL_SLAVE_CONFIG, "从库")
            init_db = "mysql_slave_db"  # 使用从库初始化
        else:
            logging.info("📝 未配置从库，全量初始化将使用主库")

        # 创建表
        for table, cfg in TABLES.items():
            if not client.query(f"EXISTS TABLE {table}").result_rows[0][0] or args.reset:
                # 使用初始化库的结构创建表
                client.command(
                    f"CREATE TABLE {table} ENGINE = ReplacingMergeTree({cfg['time_field']}) ORDER BY {cfg['id_field']} AS SELECT * FROM {init_db}.{table} LIMIT 0")

                # 转换DateTime字段
                try:
                    for col_name, col_type, *_ in client.query(f"DESCRIBE {table}").result_rows:
                        if 'DateTime' in col_type and 'DateTime64' not in col_type:
                            client.command(f"ALTER TABLE {table} MODIFY COLUMN {col_name} DateTime64(3)")
                except:
                    pass

                if args.reset:
                    db_type = "从库" if MYSQL_SLAVE_CONFIG else "主库"
                    logging.info(f"📥 {table}: 开始全量同步（使用{db_type}）")
                    # 全量同步使用初始化库
                    client.command(f"INSERT INTO {table} SELECT * FROM {init_db}.{table}")
                    count = client.query(f"SELECT COUNT(*) FROM {table}").result_rows[0][0]
                    logging.info(f"📥 {table}: 全量同步完成 {count} 条")

        client.close()
        return True

    def sync_table(client, table, cfg):
        """增量同步 - 使用主库 - 优化版：去除时间函数"""
        try:
            start_time = time.time()

            # ✅ 优化：直接获取最大时间，不使用toUnixTimestamp函数
            max_time = get_max_timestamp_optimized(client, table, cfg['time_field'])

            # ✅ 优化：直接时间比较，不用函数包裹
            count_result = client.query(
                f"SELECT COUNT(*) FROM mysql_db.{table} WHERE {cfg['time_field']} > '{max_time}' LIMIT 1"
            ).result_rows[0][0]

            if count_result > 0:
                # ✅ 优化：直接时间比较插入
                client.command(
                    f"INSERT INTO {table} SELECT * FROM mysql_db.{table} WHERE {cfg['time_field']} > '{max_time}'"
                )

                # 获取最新时间显示
                new_max_time = get_max_timestamp_optimized(client, table, cfg['time_field'])

                elapsed = time.time() - start_time
                rps = count_result / elapsed if elapsed > 0 else 0

                logging.info(f"⚡ {table}: +{count_result}条, {elapsed:.3f}s, {rps:.1f}条/s, 最新: {new_max_time}")
                return True

        except Exception as e:
            logging.error(f"❌ {table} 同步失败: {e}")
        return False

    def backfill_table(client, table, cfg):
        """补充遗漏数据 - 使用主库 - 优化版：去除时间函数"""
        try:
            start_time = time.time()

            # ✅ 优化：直接获取最大时间
            max_time = get_max_timestamp_optimized(client, table, cfg['time_field'])

            # 计算窗口开始时间
            window_start = max_time - timedelta(seconds=BACKFILL_WINDOW)

            if window_start >= max_time:
                return False

            # ✅ 优化：直接时间比较，不使用toUnixTimestamp
            mysql_ids = set(row[0] for row in client.query(
                f"SELECT {cfg['id_field']} FROM mysql_db.{table} WHERE {cfg['time_field']} BETWEEN '{window_start}' AND '{max_time}'"
            ).result_rows)

            ch_ids = set(row[0] for row in client.query(
                f"SELECT {cfg['id_field']} FROM {table} FINAL WHERE {cfg['time_field']} BETWEEN '{window_start}' AND '{max_time}'"
            ).result_rows)

            missing = mysql_ids - ch_ids
            if missing:
                ids_str = ','.join(str(id) for id in missing)
                client.command(
                    f"INSERT INTO {table} SELECT * FROM mysql_db.{table} WHERE {cfg['id_field']} IN ({ids_str})"
                )
                elapsed = time.time() - start_time
                logging.info(f"🔄 {table}: 补充{len(missing)}条, {elapsed:.3f}s")
                return True

        except Exception as e:
            logging.error(f"❌ {table} 补充失败: {e}")
        return False

    def stop_handler(sig, frame):
        nonlocal stop_flag
        stop_flag = True
        logging.info("🛑 正在退出...")

    signal.signal(signal.SIGINT, stop_handler)
    signal.signal(signal.SIGTERM, stop_handler)

    try:
        if not init():
            return

        if args.reset:
            logging.info("🔄 重置完成")
            return

        client = get_client()

        # 显示配置信息
        master_info = f"{MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}"
        if MYSQL_SLAVE_CONFIG:
            slave_info = f"{MYSQL_SLAVE_CONFIG['host']}:{MYSQL_SLAVE_CONFIG['port']}"
            logging.info(f"🚀 启动成功 (主从模式 + 时间优化)")
            logging.info(f"📊 主库: {master_info} (增量+补数据)")
            logging.info(f"📚 从库: {slave_info} (全量初始化)")
        else:
            logging.info(f"🚀 启动成功 (单库模式 + 时间优化)")
            logging.info(f"📊 数据库: {master_info} (全部操作)")

        logging.info(f"📋 表: {', '.join(TABLES.keys())} | 同步: {SYNC_INTERVAL}s | 补充: {BACKFILL_INTERVAL}s")
        logging.info(f"⚡ 优化: 去除toUnixTimestamp函数，直接时间比较")

        try:
            while not stop_flag:
                current_time = time.time()

                # 增量同步（使用主库）
                for table, cfg in TABLES.items():
                    if stop_flag:
                        break
                    sync_table(client, table, cfg)

                # 补充遗漏数据（使用主库）
                if current_time - last_backfill_time >= BACKFILL_INTERVAL:
                    logging.info("🔄 开始补充遗漏数据...")
                    for table, cfg in TABLES.items():
                        if stop_flag:
                            break
                        backfill_table(client, table, cfg)
                    last_backfill_time = current_time
                    logging.info("✅ 遗漏数据检查完成")

                if not stop_flag:
                    time.sleep(SYNC_INTERVAL)

        except KeyboardInterrupt:
            pass
        finally:
            client.close()
            logging.info("🛑 已停止")

    finally:
        # 清理锁文件
        try:
            os.unlink(lock_file)
        except:
            pass


if __name__ == "__main__":
    main()
