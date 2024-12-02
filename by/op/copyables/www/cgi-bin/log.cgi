#!/bin/sh

# 输出 HTTP 头
echo "Content-type: text/html"
echo ""

# 获取查询字符串
QUERY_STRING="${QUERY_STRING:-}"
FILE_PATH=$(echo "$QUERY_STRING" | sed -n 's/^file=\(.*\)/\1/p' | sed 's/%2F/\//g')

# 输出 HTML 头部
cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset=utf-8>
    <title>Log Viewer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .file { margin-bottom: 30px; }
        .filename {
            background: #f0f0f0;
            padding: 10px;
            margin-bottom: 10px;
            font-weight: bold;
        }
        pre {
            background: #f8f8f8;
            padding: 15px;
            border: 1px solid #ddd;
            overflow-x: auto;
            max-height: 600px;
            overflow-y: auto;
        }
        .file-list {
            list-style: none;
            padding: 0;
        }
        .file-list li {
            margin: 10px 0;
        }
        .file-list a {
            display: block;
            padding: 10px;
            background: #f0f0f0;
            text-decoration: none;
            color: #333;
            border-radius: 4px;
        }
        .file-list a:hover {
            background: #e0e0e0;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            padding: 10px;
            background: #f0f0f0;
            text-decoration: none;
            color: #333;
            border-radius: 4px;
        }
    </style>
</head>
<body>
EOF

# 检查目录是否存在
if [ ! -d "/root/log" ]; then
    echo "<p>Error: Directory /root/log does not exist!</p>"
    echo "</body></html>"
    exit 1
fi

# 如果没有指定文件，显示文件列表
if [ -z "$FILE_PATH" ]; then
    echo "<h1>Log Files in /root/log</h1>"
    echo "<ul class='file-list'>"
    find /root/log -type f | sort | while read -r file; do
        filename=$(basename "$file")
        relative_path=$(echo "$file" | sed 's|/root/log/||')
        echo "<li><a href='?file=$relative_path'>$filename</a></li>"
    done
    echo "</ul>"
else
    # 显示单个文件内容
    FULL_PATH="/root/log/$FILE_PATH"
    filename=$(basename "$FULL_PATH")

    echo "<a href='?' class='back-link'>← Back to file list</a>"
    echo "<h1>File: $filename</h1>"

    echo "<div class='file'>"
    echo "<pre>"

    if [ -r "$FULL_PATH" ]; then
        head -n 1000 "$FULL_PATH" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
    else
        echo "Error: Cannot read file $filename"
    fi

    echo "</pre>"
    echo "</div>"
fi

# 输出 HTML 尾部
echo "</body></html>"
#!/bin/sh

# 输出 HTTP 头
echo "Content-type: text/html"
echo ""

# 获取查询字符串
QUERY_STRING="${QUERY_STRING:-}"
FILE_PATH=$(echo "$QUERY_STRING" | sed -n 's/^file=\(.*\)/\1/p' | sed 's/%2F/\//g')

# 输出 HTML 头部
cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Log Viewer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .file { margin-bottom: 30px; }
        .filename {
            background: #f0f0f0;
            padding: 10px;
            margin-bottom: 10px;
            font-weight: bold;
        }
        pre {
            background: #f8f8f8;
            padding: 15px;
            border: 1px solid #ddd;
            overflow-x: auto;
            max-height: 600px;
            overflow-y: auto;
        }
        .file-list {
            list-style: none;
            padding: 0;
        }
        .file-list li {
            margin: 10px 0;
        }
        .file-list a {
            display: block;
            padding: 10px;
            background: #f0f0f0;
            text-decoration: none;
            color: #333;
            border-radius: 4px;
        }
        .file-list a:hover {
            background: #e0e0e0;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            padding: 10px;
            background: #f0f0f0;
            text-decoration: none;
            color: #333;
            border-radius: 4px;
        }
    </style>
</head>
<body>
EOF

# 检查目录是否存在
if [ ! -d "/root/log" ]; then
    echo "<p>Error: Directory /root/log does not exist!</p>"
    echo "</body></html>"
    exit 1
fi

# 如果没有指定文件，显示文件列表
if [ -z "$FILE_PATH" ]; then
    echo "<h1>Log Files in /root/log</h1>"
    echo "<ul class='file-list'>"
    find /root/log -type f | sort | while read -r file; do
        filename=$(basename "$file")
        relative_path=$(echo "$file" | sed 's|/root/log/||')
        echo "<li><a href='?file=$relative_path'>$filename</a></li>"
    done
    echo "</ul>"
else
    # 显示单个文件内容
    FULL_PATH="/root/log/$FILE_PATH"
    filename=$(basename "$FULL_PATH")

    echo "<a href='?' class='back-link'>← Back to file list</a>"
    echo "<h1>File: $filename</h1>"

    echo "<div class='file'>"
    echo "<pre>"

    if [ -r "$FULL_PATH" ]; then
        head -n 1000 "$FULL_PATH" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
    else
        echo "Error: Cannot read file $filename"
    fi

    echo "</pre>"
    echo "</div>"
fi

# 输出 HTML 尾部
echo "</body></html>"
