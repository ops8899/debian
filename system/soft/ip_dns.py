#!/usr/bin/env python3

import re
import signal
import logging
import traceback
import sys
from dnslib import *
from dnslib.server import DNSServer, DNSHandler, BaseResolver, DNSLogger

# 配置日志
logging.basicConfig(
    format='%(asctime)s [%(name)s:%(levelname)s] %(message)s',
    level=logging.INFO,
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class IPDomainResolver(BaseResolver):
    """
    处理特定格式域名的解析
    支持格式：x-x-x-x.ip.com 或 x-x-x-x.lan.com
    其中x为0-255的数字
    """
    def __init__(self, debug=False):
        self.debug = debug
        # 支持 .ip.com 和 .lan.com
        self.ip_pattern = re.compile(r'^(\d{1,3})-(\d{1,3})-(\d{1,3})-(\d{1,3})\.(ip|lan)\.com$', re.IGNORECASE)
        if debug:
            logger.setLevel(logging.DEBUG)

    def resolve(self, request, handler):
        client_ip = handler.client_address[0]
        try:
            reply = request.reply()
            qname = str(request.q.qname)
            qtype = QTYPE[request.q.qtype]
            qname_clean = qname.rstrip('.')

            logger.info(f"Request: [{client_ip}:{handler.client_address[1]}] ({handler.protocol}) / '{qname_clean}' ({qtype})")

            # 设置基本标志位
            reply.header.qr = 1      # 这是一个响应
            reply.header.aa = 1      # 权威应答
            reply.header.ra = 1      # 递归可用
            reply.header.rd = 1      # 期望递归

            match = self.ip_pattern.match(qname_clean)
            if match and request.q.qtype == QTYPE.A:  # 确保是 A 记录查询
                ip_parts = [int(match.group(i)) for i in range(1, 5)]

                if all(0 <= part <= 255 for part in ip_parts):
                    ip_addr = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}.{ip_parts[3]}"
                    logger.debug(f"Successfully resolved: {qname_clean} -> {ip_addr}")

                    # 添加问题部分（保持原始查询）
                    reply.add_question(request.q)

                    # 添加答案部分（A记录）
                    answer = RR(
                        rname=request.q.qname,  # 使用原始查询名
                        rtype=QTYPE.A,
                        rclass=1,
                        ttl=300,               # 降低 TTL 以便于测试
                        rdata=A(ip_addr)
                    )
                    reply.add_answer(answer)

                    # 添加权威部分
                    domain = qname_clean[qname_clean.find('.')+1:]  # 获取父域名
                    ns = RR(
                        rname=domain,
                        rtype=QTYPE.NS,
                        rclass=1,
                        ttl=300,
                        rdata=NS(DNSLabel('ns1.' + domain))
                    )
                    reply.add_auth(ns)

                    # 添加额外信息部分
                    ar = RR(
                        rname='ns1.' + domain,
                        rtype=QTYPE.A,
                        rclass=1,
                        ttl=300,
                        rdata=A(handler.server.server_address[0])
                    )
                    reply.add_ar(ar)

                    return reply
                else:
                    logger.warning(f"IP parts out of valid range: {qname_clean}")
                    reply.header.rcode = RCODE.NXDOMAIN
            else:
                logger.debug(f"Domain doesn't match pattern or wrong query type: {qname_clean}")
                reply.header.rcode = RCODE.NXDOMAIN

            return reply

        except Exception as e:
            logger.error(f"Error resolving {qname_clean if 'qname_clean' in locals() else 'unknown domain'}: {str(e)}")
            if self.debug:
                logger.error(traceback.format_exc())
            reply.header.rcode = RCODE.SERVFAIL
            return reply

if __name__ == '__main__':
    resolver = IPDomainResolver(debug=True)
    dns_server = DNSServer(
        resolver,
        port=5357,
        address="0.0.0.0"
    )

    logger.info("Starting DNS server...")
    try:
        dns_server.start_thread()
        while True:
            try:
                signal.pause()
            except KeyboardInterrupt:
                break
    except KeyboardInterrupt:
        pass
    finally:
        logger.info("Shutting down server...")
        dns_server.stop()
        logger.info("Server stopped")
        sys.exit(0)
