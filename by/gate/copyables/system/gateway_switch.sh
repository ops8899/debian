#!/bin/bash
echo "欢迎使用优选网关脚本"
quiet_mode=false
monitor=false

switch_score_diff=${switch_score_diff:-20}
switch_score_limit=${switch_score_limit:-70}
switch_interval=${switch_interval:-60}

log_switch_gateway_file="/root/log/gateway_switch.log"
touch $log_switch_gateway_file
log_monitor_gateway_file="/root/log/gateway_switch.log"
touch $log_monitor_gateway_file


best_proxy=""
declare -a proxy_scores
current_gateway=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--gateways)
      switch_gateways="$2"
      shift 2
      ;;
    -m|--monitor)
      monitor=true
      shift
      ;;
    -q|--quiet)
      quiet_mode=true
      shift
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

log_message() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_switch_gateway_file"; }
echo_message() { [ "$quiet_mode" = false ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$log_monitor_gateway_file"; }
extract_ip() { echo "$1" | sed -E 's#^(http://|https://|socks4://|socks5://|socks5h://)##' | cut -d: -f1; }
is_valid_ip() { [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

# if switch_gateways is not empty
if [ -z "$switch_gateways" ]; then
  echo_message "未配置可切换网关列表,保持默认网关"
  exit 1
else
  echo_message "可切换网关: $switch_gateways"
fi

echo_message "可切换网关: $switch_gateways"
echo_message "切换间隔: $switch_interval 秒"
echo_message "切换阈值: $switch_score_limit"
echo_message "切换分数差值: $switch_score_diff"

get_proxy_score() {
	local target_proxy=$1
	for entry in "${proxy_scores[@]}"; do
		IFS=':' read -r ip proxy_score <<<"$entry"
		[[ "$ip" == "$target_proxy" ]] && echo "$proxy_score" && return
	done
	echo 0
}

get_best_proxy_ip() {
  local proxy_list=$1
  if [ -z "$proxy_list" ]; then
    proxy_list=$switch_gateways
  fi
  echo_message "代理列表: $proxy_list"

	local proxycheck_result
	proxycheck_result=$(/usr/bin/proxycheck "$proxy_list" -q)

	local temp_best_proxy_ip=""
	local temp_best_score=0
	proxy_scores=() # 确保清空数组

	while IFS=',' read -r proxy score; do
		[ -z "$proxy" ] || [ -z "$score" ] && continue
		local proxy_ip
		proxy_ip=$(extract_ip "$proxy")
		if ! [[ "$score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then continue; fi
		score=$(echo "$score" | bc -l)
		if is_valid_ip "$proxy_ip" && (($(echo "$score >= 0" | bc -l))); then
			proxy_scores+=("$proxy_ip:$score")
			if (($(echo "$score > $temp_best_score" | bc -l))); then
				temp_best_proxy_ip=$proxy_ip
				temp_best_score=$score
			fi
		fi
	done <<<"$proxycheck_result"
	best_proxy="$temp_best_proxy_ip"
}

switch_gateway() {
	local new_gateway=$1
	[ -z "$new_gateway" ] && echo_message "无效的网关地址" && return
	# new_gateway" ! is_valid_ip return
	if ! is_valid_ip "$new_gateway"; then
    echo_message "无效的网关地址：$new_gateway"
    return
  fi

	[ "$new_gateway" = "$current_gateway" ] && echo_message "当前网关已经是最佳，无需切换" && return

	# 确定使用 add 还是 replace
  route_cmd="replace"
  if ! ip route show default | grep -q "default"; then
      route_cmd="add"
  fi
	if ip route $route_cmd default via "$new_gateway"; then
      log_message "成功切换到节点: $new_gateway ($(get_proxy_score "$new_gateway")),旧节点: $current_gateway $(get_proxy_score "$current_gateway")"
  else
      log_message "切换失败，无法设置网关: $new_gateway"
  fi

	current_gateway=$new_gateway
}

confirm_switch_gateway() {
	local new_gateway=$1
	get_best_proxy_ip "$switch_gateways"

	# 检查最佳网关是否和传入网关一致
	if [ "$best_proxy" != "$new_gateway" ]; then
		echo_message "无需切换：再次确认节点: $new_gateway 非最佳"
		return
	fi

	# 获取新网关和当前网关的得分
	local new_score=$(get_proxy_score "$new_gateway")
	local current_score=$(get_proxy_score "$current_gateway")

	# 检查得分有效性
	if [ -z "$new_score" ] || [ -z "$current_score" ] || ! [[ "$new_score" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$current_score" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
		echo_message "得分数据无效，无法切换：new_score=$new_score, current_score=$current_score"
		return
	fi

	# 计算分差
	local score_diff
	score_diff=$(echo "$new_score - $current_score" | bc -l)

	# 判断切换条件
  if [ "$current_gateway" == "$new_gateway" ]; then
  	echo_message "无需切换：当前网关 ($current_gateway) 已经是目标网关 ($new_gateway)"
  	return
  fi

  if (( $(echo "$score_diff < $switch_score_diff" | bc -l) == 1 )); then
  	echo_message "无需切换：分差 ($score_diff) 未达到阈值 ($switch_score_diff)"
  	return
  fi

  if (( $(echo "$current_score >= $switch_score_limit" | bc -l) == 1 )); then
  	echo_message "无需切换：当前节点得分 ($current_score) 已高于阈值 ($switch_score_limit)"
  	return
  fi

  # 如果满足所有条件，则切换网关
  echo_message "发现更优节点:$new_gateway，准备切换..."
  switch_gateway "$new_gateway"
}

monitor_gateways() {

  # 循环监控
  local current_score

  while true; do
    # 只检测当前网关，当前网关分值低于阈值时，再去确认是否需要切换
    get_best_proxy_ip "$current_gateway"
    current_score=$(get_proxy_score "$current_gateway")
    if [ -z "$current_score" ] || [ -z "$switch_score_limit" ]; then
      echo_message "警告：得分或阈值为空，跳过检测"
      continue
    fi

    if (( $(echo "$current_score >= $switch_score_limit" | bc -l) == 1 )); then
      echo_message "无需切换：当前节点: $current_gateway ($current_score) 得分大于等于阈值($switch_score_limit)"
    else
      echo_message "当前节点: $current_gateway ($current_score) 得分低于阈值($switch_score_limit),重新测试代理列表和得分："
      # 获取最佳代理 IP，并更新 proxy_scores
      get_best_proxy_ip "$switch_gateways"
      for entry in "${proxy_scores[@]}"; do
        IFS=':' read -r ip score <<<"$entry"
        echo_message "$ip: $score"
      done

      current_score=$(get_proxy_score "$current_gateway")
      if [ "$current_score" == "0" ]; then
        echo_message "当前节点: $current_gateway 得分为0，直接切换..."
        switch_gateway "$best_proxy"
      elif [ "$best_proxy" == "$current_gateway" ]; then
        echo_message "无需切换：当前节点: $current_gateway ($current_score) 与最佳节点相同"
      elif (( $(echo "$current_score < $switch_score_limit" | bc -l) == 1 )); then
        confirm_switch_gateway "$best_proxy"
      else
        echo_message "无需切换：当前节点: $current_gateway ($current_score) 得分高于阈值($switch_score_limit)"
      fi

      echo_message ""
    fi
    # 等待 10 秒
    sleep "$switch_interval"
  done
}

# if monitor is true
if [ "$monitor" = true ]; then
  # 输出可切换网关
  echo_message "可切换网关: $switch_gateways"

  # 检查是否只有一个网关
  if [[ "$switch_gateways" != *","* ]]; then
    echo_message "只有一个网关: $switch_gateways，无需监控切换"
  else
    # 启动监控
    monitor_gateways
  fi
  exit 0
fi

# 配置路由和防火墙
ip route del default
echo_message "删除默认路由,当前路由表:"
ip route

# 获取最佳代理 IP，并更新 proxy_scores
get_best_proxy_ip "$switch_gateways"
echo_message "最佳代理: $best_proxy"

if [ -z "$current_gateway" ]; then
  echo_message "当前网关为空，直接切换..."
  switch_gateway "$best_proxy"
fi
echo_message "当前网关: $current_gateway"

ip route show

ip a