#!/bin/sh

# 输出 HTML 内容类型
echo "Content-type: text/html"
echo ""

# 打印 HTML 页面头部
cat << "EOF"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenVPN Status</title>
    <style>
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 8px 12px; border: 1px solid #ddd; text-align: left; }
        th { background-color: #f4f4f4; }
    </style>
</head>
<body>
    <h1>OpenVPN Status</h1>
EOF

# 定义状态文件路径
TCP_STATUS_FILE="/root/log/openvpn_server_tcp_status.log"
UDP_STATUS_FILE="/root/log/openvpn_server_udp_status.log"

# 处理 TCP 状态
echo "<h2>TCP Status</h2>"
echo "<table>"
echo "    <tr><th>Common Name</th><th>Real Address</th><th>Virtual Address</th><th>Bytes Received (MB)</th><th>Bytes Sent (MB)</th><th>Connected Since</th></tr>"

if [ -f "$TCP_STATUS_FILE" ]; then
    # 从 TCP 状态文件读取 CLIENT_LIST 信息并生成表格行
    grep "^CLIENT_LIST" "$TCP_STATUS_FILE" | awk -F, '{
        recv=$6 / 1024 / 1024;  # Convert bytes to MB
        sent=$7 / 1024 / 1024;  # Convert bytes to MB
        printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%.2f MB</td><td>%.2f MB</td><td>%s</td></tr>\n",
        $2, $3, $4, recv, sent, $8
    }'
else
    echo "<tr><td colspan='6'>TCP Status log file not found.</td></tr>"
fi

echo "</table>"

# 处理 UDP 状态
echo "<h2>UDP Status</h2>"
echo "<table>"
echo "    <tr><th>Common Name</th><th>Real Address</th><th>Virtual Address</th><th>Bytes Received (MB)</th><th>Bytes Sent (MB)</th><th>Connected Since</th></tr>"

if [ -f "$UDP_STATUS_FILE" ]; then
    # 从 UDP 状态文件读取 CLIENT_LIST 信息并生成表格行
    grep "^CLIENT_LIST" "$UDP_STATUS_FILE" | awk -F, '{
        recv=$6 / 1024 / 1024;  # Convert bytes to MB
        sent=$7 / 1024 / 1024;  # Convert bytes to MB
        printf "<tr><td>%s</td><td>%s</td><td>%s</td><td>%.2f MB</td><td>%.2f MB</td><td>%s</td></tr>\n",
        $2, $3, $4, recv, sent, $8
    }'
else
    echo "<tr><td colspan='6'>UDP Status log file not found.</td></tr>"
fi

echo "</table>"

# 打印 HTML 页面尾部
cat << "EOF"
</body>
</html>
EOF
