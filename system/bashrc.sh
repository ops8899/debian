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

if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    echo "当前在容器中运行，跳过执行。"
else
    # Docker 快捷命令定义
    declare -A commands=(
        ["dbash"]='dbash() { [ $# -eq 0 ] && echo "用法: dbash 容器名" && return 1; docker exec -it "$1" /bin/bash || docker exec -it "$1" /bin/sh; }'

        ["dsh"]='dsh() { [ $# -eq 0 ] && echo "用法: dsh 容器名" && return 1; docker exec -it "$1" /bin/sh; }'

        ["dlogs"]='dlogs() { [ $# -eq 0 ] && echo "用法: dlogs 容器名 [行数]" && return 1; if [ -z "$2" ]; then docker logs -f "$1"; else docker logs -f --tail "$2" "$1"; fi; }'

        ["drestart"]='drestart() { local force=0; local containers=(); while [ $# -gt 0 ]; do case "$1" in -f|--force) force=1 ;; *) containers+=("$1") ;; esac; shift; done; [ ${#containers[@]} -eq 0 ] && echo "用法: drestart [-f] 容器名1 [容器名2 ...]" && return 1; echo "将要重启容器: ${containers[*]}"; if [ $force -eq 0 ]; then printf "确认重启? [y/N] "; read r; [[ ! $r =~ ^[Yy]$ ]] && echo "操作已取消。" && return 0; fi; for c in "${containers[@]}"; do docker stop "$c" -t 1 && docker start "$c" && echo "✅ 已重启 $c" || echo "❌ 重启 $c 失败"; done; }'

        ["drm"]='drm() { local force=0; local containers=(); while [ $# -gt 0 ]; do case "$1" in -f|--force) force=1 ;; *) containers+=("$1") ;; esac; shift; done; [ ${#containers[@]} -eq 0 ] && echo "用法: drm [-f] 容器名1 [容器名2 ...]" && return 1; echo "将要删除容器: ${containers[*]}"; if [ $force -eq 0 ]; then printf "确认删除? [y/N] "; read -r r; [[ ! $r =~ ^[Yy]$ ]] && echo "操作已取消。" && return 0; fi; for c in "${containers[@]}"; do docker ps -a -q -f name="^${c}$" >/dev/null 2>&1 && { docker stop "$c" -t 1 && docker rm "$c" && echo "✅ 已删除 $c"; } || echo "⚠️  容器 $c 不存在，跳过。"; done; }'

        ["drm-all"]='drm-all() { local force=0; while [ $# -gt 0 ]; do case "$1" in -f|--force) force=1 ;; esac; shift; done; if [ -z "$(docker ps -aq)" ]; then echo "当前没有任何容器，无需删除。"; return 0; fi; containers=$(docker ps -a --format "{{.Names}}"); echo "将要删除所有容器: $containers"; if [ $force -eq 0 ]; then printf "确认删除? [y/N] "; read r; [[ ! $r =~ ^[Yy]$ ]] && echo "操作已取消。" && return 0; fi; docker rm -f $(docker ps -aq) && echo "✅ 所有容器已删除。"; }'

        ["dps"]='dps() { printf "%-12s %-15s %-30s %-90s %s\n" "NAME" "STATUS" "NETWORK" "PORTS" "IMAGE"; docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}|{{.Ports}}" | sort | while IFS="|" read -r name state_info image_info port_info; do network_info=$(docker inspect --format "{{range \$k,\$v := .NetworkSettings.Networks}}{{printf \"%s:%s\" \$k \$v.IPAddress}}{{end}}" "$name" 2>/dev/null); printf "%-12s %-15s %-30s %-90s %s\n" "$name" "${state_info:0:12}" "$network_info" "${port_info}" "$image_info"; done; }'

        ["dstats"]='dstats() { docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"; }'

        ["dinfo"]='dinfo() { [ $# -eq 0 ] && echo "用法: dinfo 容器名" && return 1; docker inspect "$1" | grep -A 20 "Config\|State\|NetworkSettings"; }'

        ["dstop"]='dstop() { local force=0; local containers=(); while [ $# -gt 0 ]; do case "$1" in -f|--force) force=1 ;; *) containers+=("$1") ;; esac; shift; done; [ ${#containers[@]} -eq 0 ] && echo "用法: dstop [-f] 容器名1 [容器名2 ...]" && return 1; echo "将要停止容器: ${containers[*]}"; if [ $force -eq 0 ]; then printf "确认停止? [y/N] "; read r; [[ ! $r =~ ^[Yy]$ ]] && echo "操作已取消。" && return 0; fi; for c in "${containers[@]}"; do docker ps -q -f name="^${c}$" >/dev/null 2>&1 && docker stop "$c" && echo "✅ 已停止 $c" || echo "⚠️  容器 $c 未运行或不存在，跳过。"; done; }'

        ["dstop-all"]='dstop-all() { local force=0; while [ $# -gt 0 ]; do case "$1" in -f|--force) force=1 ;; esac; shift; done; [ $(docker ps -q | wc -l) -eq 0 ] && echo "没有正在运行的容器" && return 1; containers=$(docker ps --format "{{.Names}}"); echo "将停止所有运行中的容器: $containers"; if [ $force -eq 0 ]; then printf "确认停止? [y/N] "; read r; [[ ! $r =~ ^[Yy]$ ]] && echo "操作已取消。" && return 0; fi; docker stop -t 0 $(docker ps -q) && echo "✅ 已停止所有容器"; }'

        ["dexec"]='dexec() { [ $# -lt 2 ] && echo "用法: dexec 容器名 命令" && return 1; docker exec -it "$1" "${@:2}"; }'
    )

    # 备份 .bashrc
    [ ! -f ~/.bashrc.bak ] && cp ~/.bashrc ~/.bashrc.bak

    # 删除旧的函数定义（删除整个函数块）
    for cmd in "${!commands[@]}"; do
        sed -i "/^${cmd}()/,/^}/d" ~/.bashrc
    done

    # 添加新的函数定义
    echo "" >> ~/.bashrc
    echo "# ========== Docker 快捷命令 (自动生成) ==========" >> ~/.bashrc
    echo "# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> ~/.bashrc
    for cmd in "${!commands[@]}"; do
        if ! grep -q "^${cmd}()" ~/.bashrc 2>/dev/null; then
            echo "${commands[$cmd]}" >> ~/.bashrc
        fi
    done
    echo "# =================================================" >> ~/.bashrc

    echo "✅ 所有 Docker 快捷命令已更新完成"
fi

# 重新加载 .bashrc
source ~/.bashrc 2>/dev/null

if command -v zsh >/dev/null 2>&1; then
    zsh -c "source ~/.bashrc" 2>/dev/null
fi
