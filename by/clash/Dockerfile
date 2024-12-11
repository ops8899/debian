FROM metacubex/mihomo:latest as prep_mihomo

FROM alpine:3.12

RUN apk add --no-cache \
    bash jq curl busybox-extras tzdata iptables iproute2 bind-tools bc gawk sed coreutils && \
    ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime && \
    echo "Asia/Hong_Kong" > /etc/timezone

COPY --from=prep_mihomo /mihomo /usr/bin/mihomo
COPY --from=prep_mihomo /root/.config/mihomo/ /root/clash/
COPY copyables/ /root/

RUN chmod -R +x /root/ /usr/bin/ && \
    tar -zxvf /root/clash/ui.tar -C / && \
    rm -f /root/clash/config.yaml && \
    chmod 755 /root/ -R && \
    ls -laR /root/

# 设置工作目录
WORKDIR /root

# clash参数
ENV clash_url="" clash_include="" clash_exclude=""

# 设置入口点为 entrypoint 脚本
ENTRYPOINT ["/root/entrypoint.sh"]