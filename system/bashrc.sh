#!/bin/bash

# 要添加的路径列表
paths_to_add=(
    "/usr/sbin"
    "/sbin"
    "/usr/local/sbin"
)

# 对每个路径进行检查和添加
for new_path in "${paths_to_add[@]}"; do
    # 使用:作为分隔符检查路径是否已存在于 PATH 中
    if [[ ":$PATH:" != *":$new_path:"* ]]; then
        # 如果路径不存在，则添加到 PATH
        export PATH="$PATH:$new_path"
    fi
done

# Docker 容器内执行 bash
sed -i '/dbash()/d' ~/.bashrc && echo 'dbash() { [ $# -eq 0 ] && echo "用法: dbash 容器名" && return 1; docker exec -it "$1" /bin/bash || docker exec -it "$1" /bin/sh; }' >> ~/.bashrc

# Docker 容器内执行 sh
sed -i '/dsh()/d' ~/.bashrc && echo 'dsh() { [ $# -eq 0 ] && echo "用法: dsh 容器名" && return 1; docker exec -it "$1" /bin/sh; }' >> ~/.bashrc

# Docker 实时日志查看
sed -i '/dlogs()/d' ~/.bashrc && echo 'dlogs() { [ $# -eq 0 ] && echo "用法: dlogs 容器名 [行数]" && return 1; if [ -z "$2" ]; then docker logs -f "$1"; else docker logs -f --tail "$2" "$1"; fi; }' >> ~/.bashrc

# Docker 重启容器
sed -i '/drestart()/d' ~/.bashrc && echo 'drestart() { [ $# -eq 0 ] && echo "用法: drestart 容器名1 [容器名2 ...]" && return 1; echo "将要重启容器: $*"; printf "确认重启? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in "$@"; do docker stop "$c" -t 1 && docker start "$c" && echo "已重启 $c"; done; }' >> ~/.bashrc

# 删除容器
sed -i '/drm()/,/^}/d' ~/.bashrc && echo 'drm() { [ $# -eq 0 ] && echo "用法: drm 容器名1 [容器名2 ...]" && return 1; echo "将要删除容器: $*"; printf "确认删除? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in "$@"; do docker ps -a --format "{{.Names}}" | grep -q "^$c$" && docker stop "$c" -t 1 && docker rm "$c" && echo "已删除 $c" || echo "容器 $c 不存在，跳过。"; done; }' >> ~/.bashrc

# 删除所有容器
sed -i '/drm-all()/,/^}/d' ~/.bashrc && echo 'drm-all() { [ -z "$(docker ps -aq)" ] && echo "当前没有任何容器，无需删除。" && return 0; echo "将要删除所有容器: $(docker ps -aq)"; printf "确认删除? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker rm -f $(docker ps -aq) && echo "所有容器已删除。" || echo "操作已取消。"; }' >> ~/.bashrc

# Docker 容器IP查看
sed -i '/dip()/d' ~/.bashrc && echo 'dip() { docker ps -a --format "{{.Names}} - {{.Status}} - {{.Ports}}" | sort && echo "---网络详情---" && docker ps -q | xargs -n 1 docker inspect --format "{{.Name}} - {{range \$k,\$v := .NetworkSettings.Networks}}{{printf \"%s:%s \" \$k \$v.IPAddress}}{{end}}" | sed "s|/||g" | sort; }' >> ~/.bashrc

# Docker 查看运行容器
sed -i '/dps()/d' ~/.bashrc && echo 'dps() { if [ $# -eq 0 ]; then docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | sort; else docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | grep -i "$1" | sort; fi; }' >> ~/.bashrc

# 查看容器资源使用
sed -i '/dstats()/d' ~/.bashrc && echo 'dstats() { docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | sort; }' >> ~/.bashrc

# 查看容器详细信息
sed -i '/dinfo()/d' ~/.bashrc && echo 'dinfo() { [ $# -eq 0 ] && echo "用法: dinfo 容器名" && return 1; docker inspect "$1" | grep -A 20 "Config\|State\|NetworkSettings"; }' >> ~/.bashrc

# 查看镜像列表
sed -i '/dim()/d' ~/.bashrc && echo 'dim() { if [ $# -eq 0 ]; then docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort; else docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -i "$1" | sort; fi; }' >> ~/.bashrc

# 停止容器
sed -i '/dstop()/,/^}/d' ~/.bashrc && echo 'dstop() { [ $# -eq 0 ] && echo "用法: dstop 容器名1 [容器名2 ...]" && return 1; echo "将要停止容器: $*"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in "$@"; do docker ps --format "{{.Names}}" | grep -q "^$c$" && docker stop "$c" && echo "已停止 $c" || echo "容器 $c 未运行或不存在，跳过。"; done; }' >> ~/.bashrc

# 一键停止所有容器
sed -i '/dstop-all()/,/^}/d' ~/.bashrc && echo 'dstop-all() { [ $(docker ps -q | wc -l) -eq 0 ] && echo "没有正在运行的容器" && return 1; echo "将停止所有运行中的容器"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker stop -t 0 $(docker ps -q) && echo "已停止所有容器"; }' >> ~/.bashrc

# 进入容器执行命令
sed -i '/dexec()/d' ~/.bashrc && echo 'dexec() { [ $# -lt 2 ] && echo "用法: dexec 容器名 命令" && return 1; docker exec -it "$1" "${@:2}"; }' >> ~/.bashrc

# 容器端口映射查看
sed -i '/dport()/d' ~/.bashrc && echo 'dport() { if [ $# -eq 0 ]; then docker ps --format "{{.Names}} - {{.Ports}}" | sort; else docker ps --format "{{.Names}} - {{.Ports}}" | grep -i "$1" | sort; fi; }' >> ~/.bashrc

# 查看容器内进程
sed -i '/dtop()/d' ~/.bashrc && echo 'dtop() { [ $# -eq 0 ] && echo "用法: dtop 容器名" && return 1; docker top "$1"; }' >> ~/.bashrc


echo "所有 Docker 快捷命令已更新完成"
source ~/.bashrc
if command -v zsh >/dev/null 2>&1; then
    zsh -c "source ~/.bashrc"
fi
