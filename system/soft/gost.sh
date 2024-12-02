#!/bin/bash

VERSION="2.12.0"
ARCH="linux_amd64"
URL="https://github.com/ginuerzh/gost/releases/download/v${VERSION}/gost_${VERSION}_${ARCH}.tar.gz"
MIRROR_URL="https://kkgithub.com/ginuerzh/gost/releases/download/v${VERSION}/gost_${VERSION}_${ARCH}.tar.gz"
FILE="gost.tar.gz"

[ "$(id -u)" -ne 0 ] && echo "请使用 sudo 或 root 权限运行" && exit 1
which curl tar >/dev/null 2>&1 || (apt update && apt install curl tar -y)

download() {
    for i in {1..2}; do
        echo "尝试下载: $1 ($i/2)"
        [ "$(curl -w "%{http_code}" -f --connect-timeout 5 --max-time 5 -sL "$1" -o "$2")" -eq 200 ] && return 0
    done
    return 1
}

cd /tmp
download "$URL" "$FILE" || { echo "主地址失败，切换备用地址..."; download "$MIRROR_URL" "$FILE" || { echo "下载失败，安装中止。"; exit 1; }; }

tar -tzf "$FILE" >/dev/null 2>&1 && tar -xzf "$FILE" && chmod +x gost && mv gost /usr/bin/gost && gost -V || echo "安装失败"
