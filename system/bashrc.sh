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
      ["drestart"]='drestart() { [ $# -eq 0 ] && echo "用法: drestart 容器名1 [容器名2 ...]" && return 1; containers="$*"; echo "将要重启容器: $containers"; printf "确认重启? [y/N] "; read r; if [[ $r =~ ^[Yy]$ ]]; then for c in $containers; do docker stop "$c" -t 1 && docker start "$c" && echo "已重启 $c"; done; else echo "操作已取消。"; fi; }'
      ["drm"]='drm() { [ $# -eq 0 ] && echo "用法: drm 容器名1 [容器名2 ...]" && return 1; echo "将要删除容器: $*"; printf "确认删除? [y/N] "; read -r r; [[ $r =~ ^[Yy]$ ]] || { echo "操作已取消。"; return 0; }; for c in "$@"; do docker ps -a -q -f name="^${c}$" >/dev/null 2>&1 && { docker stop "$c" -t 1 && docker rm "$c" && echo "已删除 $c"; } || echo "容器 $c 不存在，跳过。"; done; }'
      ["drm-all"]='drm-all() { if [ -z "$(docker ps -aq)" ]; then echo "当前没有任何容器，无需删除。"; return 0; fi; containers=$(docker ps -a --format "{{.Names}}"); echo "将要删除所有容器: $containers"; printf "确认删除? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker rm -f $(docker ps -aq) && echo "所有容器已删除。" || echo "操作已取消。"; }'
      ["dps"]='dps() { printf "%-12s %-15s %-30s %-90s %s\n" "NAME" "STATUS" "NETWORK" "PORTS" "IMAGE"; docker ps -a --format "{{.Names}}|{{.Status}}|{{.Image}}|{{.Ports}}" | sort | while IFS="|" read -r name state_info image_info port_info; do network_info=$(docker inspect --format "{{range \$k,\$v := .NetworkSettings.Networks}}{{printf \"%s:%s\" \$k \$v.IPAddress}}{{end}}" "$name"); printf "%-12s %-15s %-30s %-90s %s\n" "$name" "${state_info:0:12}" "$network_info" "${port_info}" "$image_info"; done; }'
      ["dstats"]='dstats() { docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"; }'
      ["dinfo"]='dinfo() { [ $# -eq 0 ] && echo "用法: dinfo 容器名" && return 1; docker inspect "$1" | grep -A 20 "Config\|State\|NetworkSettings"; }'
      ["dstop"]='dstop() { [ $# -eq 0 ] && echo "用法: dstop 容器名1 [容器名2 ...]" && return 1; containers="$@"; echo "将要停止容器: $containers"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && for c in $containers; do docker ps -q -f name="^${c}$" >/dev/null 2>&1 && docker stop "$c" && echo "已停止 $c" || echo "容器 $c 未运行或不存在，跳过。"; done; }'
      ["dstop-all"]='dstop-all() { [ $(docker ps -q | wc -l) -eq 0 ] && echo "没有正在运行的容器" && return 1; containers=$(docker ps --format "{{.Names}}"); echo "将停止所有运行中的容器: $containers"; printf "确认停止? [y/N] "; read r; [[ $r =~ ^[Yy]$ ]] && docker stop -t 0 $(docker ps -q) && echo "已停止所有容器"; }'
      ["dexec"]='dexec() { [ $# -lt 2 ] && echo "用法: dexec 容器名 命令" && return 1; docker exec -it "$1" "${@:2}"; }'
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
          echo "${commands[$cmd]}" >> ~/.bashrc
      fi
  done
  echo "所有 Docker 快捷命令已更新完成"
fi

sed -i '/外网IP.*国内节点/d' ~/.bashrc && \
sed -i '2i echo "外网IP1(国内节点): $(timeout 3 curl -s ip.3322.net 2>/dev/null || echo \"获取失败\") | IP2(国外节点): $(timeout 3 curl -s ipinfo.io/ip 2>/dev/null || echo \"获取失败\")" &' ~/.bashrc
sed -i '/网卡信息:/d; /ip.*addr.*show/d; /ip -4 addr show/d; /echo.*网关/d' ~/.bashrc && sed -i '3i echo "网卡信息:"; ip addr show | grep -E "^[0-9]+:|inet " | grep -v "127.0.0.1" | sed "N;s/\\n/ /" | awk '\''{print "  " substr($2,1,length($2)-1) ": " $4}'\''; echo "  网关: $(ip route show default | awk '\''{print $3}'\'' | head -1)"' ~/.bashrc

# 重新加载 .bashrc
source ~/.bashrc

if command -v zsh >/dev/null 2>&1; then
    zsh -c "source ~/.bashrc"
fi