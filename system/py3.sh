#!/bin/bash
# 设置环境变量以抑制交互式提示
export DEBIAN_FRONTEND=noninteractive


echo "========================"
echo "  开始安装 Python3"
echo "========================"

apt update

apt install python3-pip -y
apt install python3-venv -y
rm -fr /opt/py3

# 设置 pip 镜像
echo "设置 pip 镜像..."
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
pip config set global.trusted-host mirrors.aliyun.com


# Check if the virtual environment already exists
if [ ! -d "/opt/py3" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv /opt/py3

    echo "Installing required packages..."
    /opt/py3/bin/pip install --no-cache-dir requests speedtest-cli
else
    echo "Python virtual environment already exists at /opt/py3"
fi

# Check if the py3 script already exists
if [ ! -f "/usr/bin/py3" ]; then
    echo "Creating py3 script..."
    echo '#!/bin/bash
/opt/py3/bin/python "$@"' > /usr/bin/py3
    chmod +x /usr/bin/py3
    echo "py3 script created and made executable"
else
    echo "py3 script already exists at /usr/bin/py3"
fi
ln -s /opt/py3/bin/speedtest-cli /usr/bin/speedtest-cli
speedtest-cli

echo "========================"
echo "  安装 Python3 完成"
echo "========================"
