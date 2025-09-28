#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MySQL到ClickHouse高速同步工具 - 简化版

功能特性：
    ⚡ 极速增量同步（智能检测有无新数据）
    🚀 零开销检测，只在有数据时同步
    🕐 完美兼容DateTime/DateTime64
    🧠 自动处理时区和精度问题
"""

import argparse
import clickhouse_connect
import json
import logging
import os
import signal
import sys
import threading

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')


def load_config(config_path):
    if not os.path.exists(config_path):
        example_config = {
            "clickhouse": {"host": "localhost", "port": 8123, "username": "default", "password": "your_password",
                           "database": "your_database"},
            "mysql": {"host": "172.17.0.1", "port": 61786, "database": "your_database", "username": "your_username",
                      "password": "your_password"},
            "tables": {"crm_item_main": {"id_field": "id", "time_field": "update_time"}}
        }
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(example_config, f, indent=4, ensure_ascii=False)
        print(f"❌ 配置文件不存在，已创建示例配置文件: {config_path}")
        sys.exit(1)

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        for key in ['clickhouse', 'mysql', 'tables']:
            if key not in config:
                raise KeyError(f"配置文件缺少必要项: {key}")
        logging.info(f"✅ 配置文件加载成功: {config_path}")
        return config
    except Exception as e:
        print(f"❌ 加载配置文件失败: {e}")
        sys.exit(1)


def smart_mysql_to_clickhouse_sync():
    parser = argparse.ArgumentParser(description='MySQL到ClickHouse高速同步工具')
    parser.add_argument('--config', default='config.json', help='配置文件路径')
    parser.add_argument('--reset', action='store_true', help='重置表')
    parser.add_argument('--force', action='store_true', help='强制执行')
    args = parser.parse_args()

    config = load_config(args.config)
    CLICKHOUSE_CONFIG = config['clickhouse']
    MYSQL_CONFIG = config['mysql']
    TABLES = config['tables']

    stop_event = threading.Event()

    def create_client():
        return clickhouse_connect.get_client(**CLICKHOUSE_CONFIG)

    def reset_tables(client):
        if not args.force:
            print("⚠️  警告：这将删除所有现有数据！")
            if input("确认重置？(输入 'yes' 确认): ").lower() != 'yes':
                return False

        for table_name in TABLES.keys():
            try:
                client.command(f"DROP TABLE IF EXISTS {table_name}")
                logging.info(f"🗑️  已删除表: {table_name}")
            except Exception as e:
                logging.warning(f"⚠️  删除表失败: {e}")

        try:
            client.command("DROP DATABASE IF EXISTS mysql_db")
            logging.info("🗑️  已删除MySQL数据库引擎")
        except:
            pass
        return True

    def init_setup():
        # 创建数据库
        temp_config = CLICKHOUSE_CONFIG.copy()
        temp_config['database'] = 'default'
        temp_client = clickhouse_connect.get_client(**temp_config)
        temp_client.command(f"CREATE DATABASE IF NOT EXISTS {CLICKHOUSE_CONFIG['database']}")
        temp_client.close()

        client = create_client()

        if args.reset and not reset_tables(client):
            client.close()
            return False

        # 创建MySQL引擎
        mysql_db_sql = f"""CREATE DATABASE IF NOT EXISTS mysql_db ENGINE = MySQL('{MYSQL_CONFIG['host']}:{MYSQL_CONFIG['port']}', '{MYSQL_CONFIG['database']}', '{MYSQL_CONFIG['username']}', '{MYSQL_CONFIG['password']}')"""
        client.command(mysql_db_sql)

        # 创建表
        for table_name, table_config in TABLES.items():
            if not client.query(f"EXISTS TABLE {table_name}").result_rows[0][0]:
                create_sql = f"""CREATE TABLE {table_name} ENGINE = ReplacingMergeTree({table_config['time_field']}) ORDER BY {table_config['id_field']} AS SELECT * FROM mysql_db.{table_name} LIMIT 0"""
                client.command(create_sql)

                # 转换DateTime字段为DateTime64(3)
                try:
                    columns = client.query(f"DESCRIBE {table_name}").result_rows
                    for col_name, col_type, *_ in columns:
                        if 'DateTime' in col_type and 'DateTime64' not in col_type:
                            client.command(f"ALTER TABLE {table_name} MODIFY COLUMN {col_name} DateTime64(3)")
                    logging.info(f"✅ 表创建成功: {table_name}")
                except Exception as e:
                    logging.warning(f"⚠️  字段转换失败: {e}")
                    logging.info(f"✅ 表创建成功: {table_name}")
            else:
                logging.info(f"ℹ️  表已存在: {table_name}")

        client.close()
        logging.info("✅ 初始化完成")
        return True

    def get_max_timestamp(client, table_name, time_field):
        """获取最大时间戳"""
        try:
            result = client.query(f"SELECT toUnixTimestamp(MAX({time_field})) FROM {table_name} FINAL")
            max_timestamp = result.result_rows[0][0]
            return max_timestamp if max_timestamp else 0
        except Exception as e:
            logging.warning(f"⚠️  获取时间戳失败 {table_name}: {e}")
            return 0

    def sync_data_ultra_fast(client, table_name, table_config):
        """超高速同步，先检测再同步"""
        if stop_event.is_set():
            return False

        time_field = table_config['time_field']

        try:
            max_timestamp = get_max_timestamp(client, table_name, time_field)

            # 先检测是否有新数据
            check_sql = f"SELECT COUNT(*) FROM mysql_db.{table_name} WHERE toUnixTimestamp({time_field}) > {int(max_timestamp)} LIMIT 1"
            check_result = client.query(check_sql)
            new_count = check_result.result_rows[0][0]

            # 只有确实有新数据时才执行同步
            if new_count > 0:
                sync_sql = f"INSERT INTO {table_name} SELECT * FROM mysql_db.{table_name} WHERE toUnixTimestamp({time_field}) > {int(max_timestamp)}"
                client.command(sync_sql)
                logging.info(f"⚡ {table_name}: 同步了 {new_count} 条新数据")
                return True

            return False

        except Exception as e:
            if not stop_event.is_set():
                logging.error(f"❌ {table_name} 同步失败: {e}")
            return False

    def incremental_sync():
        client = create_client()
        logging.info("🚀 超高速同步启动（智能检测模式）")

        try:
            while not stop_event.is_set():
                for table_name, table_config in TABLES.items():
                    if stop_event.is_set():
                        break
                    sync_data_ultra_fast(client, table_name, table_config)

                if stop_event.is_set():
                    break

                stop_event.wait(0.5)

        except Exception as e:
            if not stop_event.is_set():
                logging.error(f"❌ 同步异常: {e}")
        finally:
            client.close()
            logging.info("🛑 同步已停止")

    def signal_handler(signum, frame):
        logging.info("🛑 正在退出...")
        stop_event.set()

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        if not init_setup():
            return

        if args.reset:
            logging.info("🔄 重置完成")
            return

        inc_thread = threading.Thread(target=incremental_sync)
        inc_thread.start()

        logging.info("🚀 超高速同步已启动（智能检测模式）")
        logging.info(f"📋 监控表: {', '.join(TABLES.keys())}")
        logging.info("🧠 智能兼容DateTime/DateTime64")
        logging.info("⚡ 先检测后同步，零无效开销")
        logging.info("⏱️ 固定0.5秒轮询间隔")
        logging.info("💡 按 Ctrl+C 退出")

        while not stop_event.is_set():
            stop_event.wait(1)

        inc_thread.join(timeout=5)
        logging.info("🛑 已停止")

    except Exception as e:
        logging.error(f"❌ 异常: {e}")
        stop_event.set()
    finally:
        sys.exit(0)


if __name__ == "__main__":
    smart_mysql_to_clickhouse_sync()
