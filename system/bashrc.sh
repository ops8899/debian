#!/bin/bash

# 要添加的路径列表
paths_to_add=(
    "/usr/sbin"
    "/sbin"
    "/usr/local/sbin"
)

# 对每个路径进行检查和添加
for new_path in "${paths_to_add[@]}"; do
    if [[ ":$PATH:" != *":$new_path:"* ]]; then
        export PATH="$PATH:$new_path"
    fi
done

# Docker 快捷命令定义
declare -A commands=(
    ["dbash"]='dbash() { [ $# -eq 0 ] && echo "用法: dbash 容器名" && return 1; docker exec -it "$1" /bin/bash || docker exec -it "$1" /bin/sh; }'
    ["dsh"]='dsh() { [ $# -eq 0 ] && echo "用法: dsh 容器名" && return 1; docker exec -it "$1" /bin/sh; }'
    ["dlogs"]='dlogs() { [ $# -eq 0 ] && echo "用法: dlogs 容器名 [行数]" && return 1; if [ -z "$2" ]; then docker logs -f "$1"; else docker logs -f --tail "$2" "$1"; fi; }'
    ["drestart"]='drestart() { [ $# -eq 0 ] && echo "用法: drestart 容器名1 [容器名2 ...]" && return 1; containers=$(echo "$*" | tr " " "\n" | sort | tr "\n" " "); echo "将要重启容器: $containers"; printf "确认重启? [y/N] "; read r; if [[ $r =~ ^[Yy]$ ]]; then for c in $containers; do docker stop "$c" -t 1 && docker start "$c" && echo "已重启 $c"; done; else echo "操作已取消。"; fi; }'
    ["drm"]='drm() { [ $# -eq 0 ] && echo "用法: drm 容器名1 [容器名2 ...]" && return 1; containers=$(echo "$*" | tr " " "\n" | sort | tr "\n" " "); echo "将要删除容器: $containers"; printf "确认删除? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in $containers; do docker ps -a --format "{{.Names}}" | grep -q "^$c$" && docker stop "$c" -t 1 && docker rm "$c" && echo "已删除 $c" || echo "容器 $c 不存在，跳过。"; done; }'
    ["drm-all"]='drm-all() { if [ -z "$(docker ps -aq)" ]; then echo "当前没有任何容器，无需删除。"; return 0; fi; containers=$(docker ps -a --format "{{.Names}}" | sort | tr "\n" " "); echo "将要删除所有容器: $containers"; printf "确认删除? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker rm -f $(docker ps -aq) && echo "所有容器已删除。" || echo "操作已取消。"; }'
    ["dip"]='dip() { docker ps -a --format "{{.Names}} - {{.Status}} - {{.Ports}}" | sort && echo "---网络详情---" && docker ps -a --format "{{.Names}}" | sort | while read name; do docker inspect "$name" --format "{{.Name}} - {{range \$k,\$v := .NetworkSettings.Networks}}{{printf \"%s:%s \" \$k \$v.IPAddress}}{{end}}" | sed "s|/||g"; done; }'
    ["dps"]='dps() { if [ $# -eq 0 ]; then docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | sort; else docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}" | grep -i "$1" | sort; fi; }'
    ["dstats"]='dstats() { docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | sort; }'
    ["dinfo"]='dinfo() { [ $# -eq 0 ] && echo "用法: dinfo 容器名" && return 1; docker inspect "$1" | grep -A 20 "Config\|State\|NetworkSettings"; }'
    ["dim"]='dim() { if [ $# -eq 0 ]; then docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort; else docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -i "$1" | sort; fi; }'
    ["dstop"]='dstop() { [ $# -eq 0 ] && echo "用法: dstop 容器名1 [容器名2 ...]" && return 1; containers=$(echo "$*" | tr " " "\n" | sort | tr "\n" " "); echo "将要停止容器: $containers"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in $containers; do docker ps --format "{{.Names}}" | grep -q "^$c$" && docker stop "$c" && echo "已停止 $c" || echo "容器 $c 未运行或不存在，跳过。"; done; }'
    ["dstop-all"]='dstop-all() { [ $(docker ps -q | wc -l) -eq 0 ] && echo "没有正在运行的容器" && return 1; containers=$(docker ps --format "{{.Names}}" | sort | tr "\n" " "); echo "将停止所有运行中的容器: $containers"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker stop -t 0 $(docker ps -q) && echo "已停止所有容器"; }'
    ["dexec"]='dexec() { [ $# -lt 2 ] && echo "用法: dexec 容器名 命令" && return 1; docker exec -it "$1" "${@:2}"; }'
    ["dport"]='dport() { if [ $# -eq 0 ]; then docker ps --format "{{.Names}} - {{.Ports}}" | sort; else docker ps --format "{{.Names}} - {{.Ports}}" | grep -i "$1" | sort; fi; }'
    ["dtop"]='dtop() { [ $# -eq 0 ] && echo "用法: dtop 容器名" && return 1; docker top "$1"; }'
)


# 更新命令到 .bashrc
# 首先，删除旧的函数定义
for cmd in "${!commands[@]}"; do
    sed -i "/^$cmd()/d" ~/.bashrc
done

# 然后，添加新的函数定义，确保每个函数都单独成行
for cmd in "${!commands[@]}"; do
    # 在写入之前先检查函数是否已存在
    if ! grep -q "^$cmd()" ~/.bashrc; then
        # 添加一个换行符确保函数定义独立成行
        echo "" >> ~/.bashrc
        echo "${commands[$cmd]}" >> ~/.bashrc
    fi
done

echo "所有 Docker 快捷命令已更新完成"

# 添加一个空行
echo "" >> ~/.bashrc

# 重新加载 .bashrc
source ~/.bashrc

if command -v zsh >/dev/null 2>&1; then
    zsh -c "source ~/.bashrc"
fi