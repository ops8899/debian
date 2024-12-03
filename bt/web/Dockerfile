# 使用官方 Debian 12 基础镜像
FROM debian:12

# 设置环境变量以避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 更新包管理器并安装 systemd 和相关依赖
RUN apt-get update && apt-get install -y \
    systemd systemd-sysv dbus git ca-certificates && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 克隆 Git 仓库并执行脚本
RUN git clone https://github.com/ops8899/debian.git /opt/debian && \
    chmod +x -R /opt/debian/system/ && \
    cd /opt/debian/system/ && \
    bash 1.sh -cn -ssh-port 25555

RUN wget -O install.sh https://install.baota.sbs/install/install_6.0.sh && echo 'y'|bash install.sh
# 创建必要的目录
VOLUME [ "/sys/fs/cgroup" ]

# 添加自定义的 entrypoint 脚本
COPY copyables/ /root/
RUN mkdir -p /run/sshd && \
    chmod +x /root/entrypoint.sh

# 设置 entrypoint
ENTRYPOINT ["/root/entrypoint.sh"]

# 默认不传递额外参数
CMD []