# 使用 Debian 12 slim 作为基础镜像
FROM debian:12-slim

# 设置环境变量以避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新包管理器，安装所需的包
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git ca-certificates && \
    update-ca-certificates

COPY copyables/entrypoint.sh /root/

# 安装基础
RUN chmod +x /root/*.sh && \
    git clone https://github.com/ops8899/debian.git /opt/debian && \
    chmod +x -R /opt/debian/ && \
    cd /opt/debian/system && \
    bash 1.sh

RUN cd /tmp && curl -sSO http://v920.hostcli.com/install/install_6.0.sh;echo 'yes'|bash install_6.0.sh

# 设置入口点为 entrypoint 脚本
ENTRYPOINT ["/root/entrypoint.sh"]
