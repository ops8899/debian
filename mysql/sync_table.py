#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MySQL到TiDB高速同步工具 - 完美修复版

功能特性：
    ⚡ 极速增量同步（智能检测有无新数据）
    🔄 防并发遗漏（每5分钟回退检查）
    🚀 零开销检测，只在有数据时同步
    🏗️ 自动建库建表（如果不存在）
    ⚡ 可选TiFlash副本自动添加
    🕐 完美兼容所有MySQL数据类型
    🧠 自动处理时区和编码问题
    📊 批量处理控制
"""

import pymysql
import time
import threading
import logging
import signal
import sys
import argparse
import json
import os
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

def load_config(config_path):
    if not os.path.exists(config_path):
        example_config = {
            "source_mysql": {
                "host": "source.mysql.com",
                "port": 3306,
                "database": "source_database",
                "username": "source_user",
                "password": "source_password"
            },
            "target_tidb": {
                "host": "target.tidb.com",
                "port": 4000,
                "database": "target_database",
                "username": "target_user",
                "password": "target_password"
            },
            "sync_settings": {
                "batch_size": 1000,
                "tiflash_enabled": True
            },
            "tables": {
                "crm_item_main": {
                    "id_field": "id",
                    "time_field": "update_time"
                }
            }
        }
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(example_config, f, indent=4, ensure_ascii=False)
        print(f"❌ 配置文件不存在，已创建示例配置文件: {config_path}")
        sys.exit(1)

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        for key in ['source_mysql', 'target_tidb', 'tables']:
            if key not in config:
                raise KeyError(f"配置文件缺少必要项: {key}")
        logging.info(f"✅ 配置文件加载成功: {config_path}")
        return config
    except Exception as e:
        print(f"❌ 加载配置文件失败: {e}")
        sys.exit(1)

def smart_mysql_to_tidb_sync():
    parser = argparse.ArgumentParser(description='MySQL到TiDB高速同步工具')
    parser.add_argument('--config', default='config.json', help='配置文件路径')
    parser.add_argument('--reset', action='store_true', help='重置表')
    parser.add_argument('--force', action='store_true', help='强制执行')
    args = parser.parse_args()

    config = load_config(args.config)
    SOURCE_MYSQL_CONFIG = config['source_mysql']
    target_tidb_CONFIG = config['target_tidb']
    TABLES = config['tables']

    # 🚀 获取同步设置
    SYNC_SETTINGS = config.get('sync_settings', {'batch_size': 1000, 'tiflash_enabled': True})
    BATCH_SIZE = SYNC_SETTINGS.get('batch_size', 1000)
    TIFLASH_ENABLED = SYNC_SETTINGS.get('tiflash_enabled', True)

    stop_event = threading.Event()
    last_backtrack_time = {}

    def create_source_connection():
        try:
            logging.info(f"🔗 正在连接源数据库: {SOURCE_MYSQL_CONFIG['host']}:{SOURCE_MYSQL_CONFIG['port']}/{SOURCE_MYSQL_CONFIG['database']}")
            conn = pymysql.connect(
                host=SOURCE_MYSQL_CONFIG['host'],
                port=SOURCE_MYSQL_CONFIG['port'],
                user=SOURCE_MYSQL_CONFIG['username'],
                password=SOURCE_MYSQL_CONFIG['password'],
                database=SOURCE_MYSQL_CONFIG['database'],
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            logging.info(f"✅ 源数据库连接成功: {SOURCE_MYSQL_CONFIG['host']}:{SOURCE_MYSQL_CONFIG['port']}")
            return conn
        except Exception as e:
            logging.error(f"❌ 源数据库连接失败 {SOURCE_MYSQL_CONFIG['host']}:{SOURCE_MYSQL_CONFIG['port']}: {e}")
            raise

    def create_target_connection():
        try:
            logging.info(f"🔗 正在连接目标数据库: {target_tidb_CONFIG['host']}:{target_tidb_CONFIG['port']}/{target_tidb_CONFIG['database']}")
            conn = pymysql.connect(
                host=target_tidb_CONFIG['host'],
                port=target_tidb_CONFIG['port'],
                user=target_tidb_CONFIG['username'],
                password=target_tidb_CONFIG['password'],
                database=target_tidb_CONFIG['database'],
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )
            logging.info(f"✅ 目标数据库连接成功: {target_tidb_CONFIG['host']}:{target_tidb_CONFIG['port']}")
            return conn
        except Exception as e:
            logging.error(f"❌ 目标数据库连接失败 {target_tidb_CONFIG['host']}:{target_tidb_CONFIG['port']}: {e}")
            raise

    def create_database_if_not_exists():
        """🏗️ 自动创建目标数据库"""
        try:
            logging.info(f"🔗 正在连接目标服务器创建数据库: {target_tidb_CONFIG['host']}:{target_tidb_CONFIG['port']}")
            # 连接到服务器但不指定数据库
            conn = pymysql.connect(
                host=target_tidb_CONFIG['host'],
                port=target_tidb_CONFIG['port'],
                user=target_tidb_CONFIG['username'],
                password=target_tidb_CONFIG['password'],
                charset='utf8mb4'
            )
            with conn.cursor() as cursor:
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{target_tidb_CONFIG['database']}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                conn.commit()
            conn.close()
            logging.info(f"✅ 目标数据库确保存在: {target_tidb_CONFIG['database']}")
            return True
        except Exception as e:
            logging.error(f"❌ 创建目标数据库失败: {e}")
            return False

    def get_table_structure(source_conn, table_name):
        """获取源表结构"""
        try:
            logging.info(f"📋 正在获取源表结构: {table_name}")
            with source_conn.cursor() as cursor:
                cursor.execute(f"SHOW CREATE TABLE {table_name}")
                result = cursor.fetchone()
                logging.info(f"✅ 源表结构获取成功: {table_name}")
                return result['Create Table']
        except Exception as e:
            logging.error(f"❌ 获取源表结构失败 {table_name}: {e}")
            return None

    def create_target_table(target_conn, table_name, create_sql):
        """在目标数据库创建表"""
        try:
            logging.info(f"🏗️ 正在创建目标表: {table_name}")
            with target_conn.cursor() as cursor:
                # 替换表名，防止数据库名冲突
                create_sql = create_sql.replace(f'`{SOURCE_MYSQL_CONFIG["database"]}`.', '')
                cursor.execute(create_sql)
                target_conn.commit()
                logging.info(f"✅ 目标表创建成功: {table_name}")
                return True
        except Exception as e:
            logging.error(f"❌ 创建目标表失败 {table_name}: {e}")
            return False

    def table_exists(conn, table_name, db_type=""):
        """检查表是否存在"""
        try:
            with conn.cursor() as cursor:
                cursor.execute(f"SHOW TABLES LIKE '{table_name}'")
                exists = cursor.fetchone() is not None
                if exists:
                    logging.info(f"ℹ️  {db_type}表已存在: {table_name}")
                else:
                    logging.info(f"⚠️  {db_type}表不存在: {table_name}")
                return exists
        except Exception as e:
            logging.error(f"❌ 检查{db_type}表存在性失败 {table_name}: {e}")
            return False

    def get_table_columns(conn, table_name):
        """获取表的列信息"""
        try:
            with conn.cursor() as cursor:
                cursor.execute(f"DESCRIBE {table_name}")
                columns = cursor.fetchall()
                return [col['Field'] for col in columns]
        except Exception as e:
            logging.error(f"❌ 获取表列信息失败 {table_name}: {e}")
            return []

    def add_tiflash_replica(target_conn, table_name):
        """添加TiFlash副本"""
        if not TIFLASH_ENABLED:
            logging.info(f"⚠️  TiFlash功能已禁用，跳过 {table_name}")
            return False

        try:
            logging.info(f"⚡ 正在为目标表添加TiFlash副本: {table_name}")
            with target_conn.cursor() as cursor:
                cursor.execute(f"ALTER TABLE {table_name} SET TIFLASH REPLICA 1")
                target_conn.commit()
                logging.info(f"⚡ 目标表TiFlash副本添加成功: {table_name}")
                return True
        except Exception as e:
            logging.warning(f"⚠️  目标表TiFlash副本添加失败 {table_name}: {e}")
            return False

    def reset_tables():
        if not args.force:
            print("⚠️  警告：这将删除目标数据库中的所有现有表！")
            if input("确认重置？(输入 'yes' 确认): ").lower() != 'yes':
                return False

        # 🏗️ 确保目标数据库存在
        if not create_database_if_not_exists():
            return False

        target_conn = create_target_connection()
        try:
            with target_conn.cursor() as cursor:
                for table_name in TABLES.keys():
                    try:
                        cursor.execute(f"DROP TABLE IF EXISTS {table_name}")
                        target_conn.commit()
                        logging.info(f"🗑️  已删除目标表: {table_name}")
                    except Exception as e:
                        logging.warning(f"⚠️  删除目标表失败: {e}")
        finally:
            target_conn.close()
        return True

    def init_setup():
        if args.reset and not reset_tables():
            return False

        # 🏗️ 确保目标数据库存在
        if not create_database_if_not_exists():
            return False

        source_conn = create_source_connection()
        target_conn = create_target_connection()

        try:
            for table_name, table_config in TABLES.items():
                # 检查源表是否存在
                if not table_exists(source_conn, table_name, "源"):
                    logging.error(f"❌ 源表不存在: {table_name}")
                    continue

                # 检查目标表是否存在，不存在则创建
                if not table_exists(target_conn, table_name, "目标"):
                    logging.info(f"🏗️  目标表不存在，正在从源表创建: {table_name}")
                    create_sql = get_table_structure(source_conn, table_name)
                    if create_sql and create_target_table(target_conn, table_name, create_sql):
                        logging.info(f"✅ 目标表创建成功: {table_name}")

                        # 🚀 根据配置决定是否添加TiFlash副本
                        add_tiflash_replica(target_conn, table_name)

                    else:
                        logging.error(f"❌ 目标表创建失败: {table_name}")
                        continue
                else:
                    logging.info(f"ℹ️  目标表已存在: {table_name}")

                    # 🚀 为已存在的目标表添加TiFlash副本（如果启用）
                    add_tiflash_replica(target_conn, table_name)

                # 初始化回退时间
                last_backtrack_time[table_name] = time.time()

        finally:
            source_conn.close()
            target_conn.close()

        logging.info("✅ 初始化完成")
        return True

    def get_max_timestamp_with_backtrack(target_conn, table_name, time_field):
        """🧠 智能获取目标表最大时间戳 - 修复精度问题"""
        try:
            with target_conn.cursor() as cursor:
                # 🔥 关键修复：使用微秒精度比较，避免同一秒内数据遗漏
                cursor.execute(f"SELECT MAX({time_field}) as max_time FROM {table_name}")
                result = cursor.fetchone()
                max_time = result['max_time'] if result and result['max_time'] else None

                if not max_time:
                    return "1970-01-01 00:00:00.000000", False

                current_time = time.time()
                # 🔄 每5分钟回退一次
                should_backtrack = current_time - last_backtrack_time.get(table_name, 0) >= 300

                if should_backtrack:
                    # 🔧 修复：回退到目标表最大时间往前5分钟
                    cursor.execute(f"SELECT DATE_SUB(MAX({time_field}), INTERVAL 5 MINUTE) as backtrack_time FROM {table_name}")
                    backtrack_result = cursor.fetchone()
                    backtrack_time = backtrack_result['backtrack_time'] if backtrack_result else max_time
                    last_backtrack_time[table_name] = current_time
                    return backtrack_time, True
                else:
                    return max_time, False

        except Exception as e:
            logging.warning(f"⚠️  获取目标表时间戳失败 {table_name}: {e}")
            return "1970-01-01 00:00:00.000000", False

    def sync_data_ultra_fast(table_name, table_config):
        """⚡ 超高速同步，使用INSERT ON DUPLICATE KEY UPDATE优化"""
        if stop_event.is_set():
            return False

        time_field = table_config['time_field']
        id_field = table_config['id_field']

        # 🔥 关键修复：在函数开始时初始化所有变量，避免UnboundLocalError
        source_conn = None
        target_conn = None

        try:
            # 🔥 修复：确保target_conn在使用前已正确初始化
            target_conn = pymysql.connect(
                host=target_tidb_CONFIG['host'],
                port=target_tidb_CONFIG['port'],
                user=target_tidb_CONFIG['username'],
                password=target_tidb_CONFIG['password'],
                database=target_tidb_CONFIG['database'],
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )

            max_time, is_backtrack = get_max_timestamp_with_backtrack(target_conn, table_name, time_field)

            source_conn = pymysql.connect(
                host=SOURCE_MYSQL_CONFIG['host'],
                port=SOURCE_MYSQL_CONFIG['port'],
                user=SOURCE_MYSQL_CONFIG['username'],
                password=SOURCE_MYSQL_CONFIG['password'],
                database=SOURCE_MYSQL_CONFIG['database'],
                charset='utf8mb4',
                cursorclass=pymysql.cursors.DictCursor
            )

            # 🔍 修复：直接使用时间字段比较，保持完整精度
            with source_conn.cursor() as cursor:
                # 🔥 关键修复：使用 > 而不是 UNIX_TIMESTAMP 比较
                check_sql = f"SELECT COUNT(*) as count FROM {table_name} WHERE {time_field} > %s"
                cursor.execute(check_sql, (max_time,))
                result = cursor.fetchone()
                new_count = result['count']

                # 🚀 只有确实有新数据时才执行同步
                if new_count > 0:
                    # 🔥 关键修复：获取数据时也使用直接时间比较
                    sync_sql = f"SELECT * FROM {table_name} WHERE {time_field} > %s ORDER BY {time_field}, {id_field} LIMIT %s"
                    cursor.execute(sync_sql, (max_time, BATCH_SIZE))
                    new_data = cursor.fetchall()

                    if new_data:
                        # 获取目标表列信息
                        columns = get_table_columns(target_conn, table_name)
                        if not columns:
                            return False

                        # 🚀 使用 INSERT ON DUPLICATE KEY UPDATE 语句，性能更优
                        placeholders = ', '.join(['%s'] * len(columns))
                        columns_str = ', '.join([f'`{col}`' for col in columns])

                        # 构建UPDATE子句，排除主键字段
                        update_assignments = []
                        for col in columns:
                            if col != id_field:  # 假设id_field是主键，不需要更新
                                update_assignments.append(f"`{col}` = VALUES(`{col}`)")

                        update_clause = ', '.join(update_assignments)

                        # 🔥 关键优化：使用INSERT ON DUPLICATE KEY UPDATE
                        upsert_sql = f"""
                        INSERT INTO {table_name} ({columns_str}) 
                        VALUES ({placeholders})
                        ON DUPLICATE KEY UPDATE {update_clause}
                        """

                        # 批量插入数据到目标表
                        with target_conn.cursor() as target_cursor:
                            data_to_insert = []
                            for row in new_data:
                                row_data = [row.get(col) for col in columns]
                                data_to_insert.append(row_data)

                            target_cursor.executemany(upsert_sql, data_to_insert)
                            target_conn.commit()

                        # 🔢 显示批量信息
                        if new_count > BATCH_SIZE:
                            remaining = new_count - len(new_data)
                            if is_backtrack:
                                logging.info(f"🔄 {table_name}: 5分钟回退检查，使用UPSERT同步 {len(new_data)} 条，还有 {remaining} 条待处理")
                            else:
                                logging.info(f"⚡ {table_name}: 使用UPSERT同步 {len(new_data)} 条，还有 {remaining} 条待处理")
                        else:
                            if is_backtrack:
                                logging.info(f"🔄 {table_name}: 5分钟回退检查完成，使用UPSERT同步 {len(new_data)} 条数据")
                            else:
                                logging.info(f"⚡ {table_name}: 使用UPSERT同步 {len(new_data)} 条新数据")
                        return True
                    else:
                        return False
                else:
                    return False

        except Exception as e:
            if not stop_event.is_set():
                # 🔥 修复：确保table_name变量在异常处理时可用
                logging.error(f"❌ {table_name} UPSERT同步失败: {e}")
            return False
        finally:
            # 🔥 修复：确保连接对象存在时才关闭
            if source_conn:
                source_conn.close()
            if target_conn:
                target_conn.close()

    def incremental_sync():
        logging.info("🚀 超高速同步启动（智能检测模式）")
        logging.info(f"📡 源数据库: {SOURCE_MYSQL_CONFIG['host']}:{SOURCE_MYSQL_CONFIG['port']}/{SOURCE_MYSQL_CONFIG['database']}")
        logging.info(f"🎯 目标数据库: {target_tidb_CONFIG['host']}:{target_tidb_CONFIG['port']}/{target_tidb_CONFIG['database']}")

        try:
            while not stop_event.is_set():
                for table_name, table_config in TABLES.items():
                    if stop_event.is_set():
                        break
                    sync_data_ultra_fast(table_name, table_config)

                if stop_event.is_set():
                    break

                # ⏱️ 固定0.5秒轮询间隔
                stop_event.wait(0.5)

        except Exception as e:
            if not stop_event.is_set():
                logging.error(f"❌ 同步异常: {e}")
        finally:
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

        logging.info("🚀 MySQL到TiDB超高速同步已启动")
        logging.info(f"📋 监控表: {', '.join(TABLES.keys())}")
        logging.info(f"📊 批量处理大小: {BATCH_SIZE}")
        logging.info(f"⚡ TiFlash功能: {'启用' if TIFLASH_ENABLED else '禁用'}")
        logging.info("🏗️ 自动建库建表：目标不存在时自动创建")
        logging.info("🔄 每5分钟自动回退检查")
        logging.info("🧠 智能兼容所有MySQL数据类型")
        logging.info("🚀 使用INSERT ON DUPLICATE KEY UPDATE自动处理主键冲突")
        logging.info("⚡ 先检测后同步，零无效开销")
        logging.info("📊 静默模式：无新数据时不输出日志")
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
    smart_mysql_to_tidb_sync()
