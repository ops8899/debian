#!/bin/bash
# 脚本名称：proxycheck.sh

QUIET_MODE=false
PROXY_LIST=""
MAX_JOBS=5  # 最大并发任务数

while [[ $# -gt 0 ]]; do
    case $1 in
        -q|--quiet) QUIET_MODE=true ;;
        -p|--proxy) PROXY_LIST="$2"; shift ;;
        -j|--jobs) MAX_JOBS="$2"; shift ;;
        *)
            if [ -z "$PROXY_LIST" ]; then
                PROXY_LIST="$1"
            else
                PROXY_LIST="$PROXY_LIST,$1"
            fi
            ;;
    esac
    shift
done

if [ -z "$PROXY_LIST" ]; then
    echo "错误：未提供代理列表。请直接提供代理地址或使用 -p 参数指定代理列表。"
    echo "用法: $0 [-q|--quiet] [-j|--jobs num] [-p|--proxy proxy_list] [proxy1 proxy2 ...]"
    exit 1
fi

IFS=',' read -ra PROXIES <<< "$PROXY_LIST"

process_proxy() {
    local proxy=$1
    local protocol="socks5h"
    local auth=""
    local host=""
    local port=""

    if [[ $proxy == socks5://* ]]; then
        protocol="socks5"
        proxy=${proxy#socks5://}
    elif [[ $proxy == socks5h://* ]]; then
        protocol="socks5h"
        proxy=${proxy#socks5h://}
    elif [[ $proxy == http://* ]]; then
        proxy=${proxy#http://}
    fi

    if [[ $proxy == *@* ]]; then
        auth=${proxy%@*}
        proxy=${proxy#*@}
    fi

    if [[ $proxy == *:* ]]; then
        host=${proxy%:*}
        port=${proxy#*:}
    else
        host=$proxy
        port="1081"
    fi

    if [ -n "$auth" ]; then
        echo "${protocol}://${auth}@${host}:${port}"
    else
        echo "${protocol}://${host}:${port}"
    fi
}

for i in "${!PROXIES[@]}"; do
    PROXIES[$i]=$(process_proxy "${PROXIES[$i]}")
done

[ "$QUIET_MODE" = false ] && echo "代理列表:" && printf '%s\n' "${PROXIES[@]}"

URLS=(
    "http://www.google-analytics.com/generate_204"
    "http://cp.cloudflare.com/generate_204"
    "http://edge.microsoft.com/captiveportal/generate_204"
)

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
# 定义超时时间变量
TIMEOUT=5

run_test() {
    local proxy=$1 url=$2 target=$(echo "$url" | awk -F[/:] '{print $4}') attempt=$3
     result=$(curl -s -o /dev/null -w "%{time_total},%{http_code}\n" -x "$proxy" -k \
                 --connect-timeout $TIMEOUT --max-time $TIMEOUT \
                 -H "Accept-Encoding: identity" \
                 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                 "$url" 2>/dev/null)
        if [ $? -eq 0 ]; then
            IFS=',' read time code <<< "$result"
            if { [[ $code == "204" || $code == "200" ]] && [[ $(echo "$time < $TIMEOUT" | bc -l) == 1 ]]; }; then
            latency=$(echo "$time * 1000"|bc|cut -d'.' -f1)
            echo "${proxy},${target},${attempt},${latency},success,${code}" >> "$TEMP_DIR/results.csv"
            [ "$QUIET_MODE" = false ] && echo "$proxy|$target|$attempt|${latency}ms ✓"
        else
            echo "${proxy},${target},${attempt},2000,failed,${code}" >> "$TEMP_DIR/results.csv"
            [ "$QUIET_MODE" = false ] && echo "$proxy|$target|$attempt|失败(${time}s) ✗"
        fi
    else
        echo "${proxy},${target},${attempt},2000,failed,0" >> "$TEMP_DIR/results.csv"
        [ "$QUIET_MODE" = false ] && echo "$proxy|$target|$attempt|错误 ✗"
    fi
}

[ "$QUIET_MODE" = false ] && echo "开始测试..." && echo "------------------------"

run_jobs() {
    local -i job_count=0
    for proxy in "${PROXIES[@]}"; do
        for url in "${URLS[@]}"; do
            for j in {1..3}; do
                run_test "$proxy" "$url" "$j" &
                ((job_count++))
                if [ $job_count -ge $MAX_JOBS ]; then
                    wait -n
                    ((job_count--))
                fi
            done
        done
    done
    wait
}

run_jobs

if [ "$QUIET_MODE" = false ]; then
    for proxy in "${PROXIES[@]}"; do
        echo -e "\n测试代理: $proxy"
        echo "--------------------------------------------------------------------------------"
        printf "%-35s | %-15s | %-15s | %-15s\n" "目标" "测试1" "测试2" "测试3"
        echo "--------------------------------------------------------------------------------"
        for url in "${URLS[@]}"; do
            target=$(echo "$url" | awk -F[/:] '{print $4}')
            [ ${#target} -gt 32 ] && target="${target:0:29}..."
            printf "%-35s |" "$target"
            for j in {1..3}; do
                result=$(grep "^${proxy},${target},${j}," "$TEMP_DIR/results.csv")
                IFS=',' read _ _ _ latency status _ <<< "$result"
                if [ "$status" = "success" ]; then
                    printf " %-15s |" "${latency}ms"
                else
                    printf " %-15s |" "失败"
                fi
            done
            echo
        done
    done
    echo -e "\n=== 最终统计 ===\n"
    printf "%-50s | %-10s | %-12s | %-10s\n" "代理" "成功率" "平均延迟" "综合得分"
    echo "--------------------------------------------------------------------------------"
fi

best_proxy="" best_score=0 best_latency=0
# 在计算每个代理的最终得分后
for proxy in "${PROXIES[@]}"; do
    total_tests=0 successful_tests=0 total_latency=0
    while IFS=',' read -r _ _ _ latency status _; do
        ((total_tests++))
        if [ "$status" = "success" ]; then
            ((successful_tests++))
            total_latency=$((total_latency + latency))
        fi
    done < <(grep "^${proxy}," "$TEMP_DIR/results.csv")

    success_rate=$(echo "scale=2; $successful_tests / $total_tests * 100" | bc)
    avg_latency=$([ $successful_tests -gt 0 ] && echo "scale=0; $total_latency / $successful_tests" | bc || echo 2000)

    latency_score=$(awk -v al=$avg_latency 'BEGIN {
        if (al <= 50) print 100
        else if (al <= 100) print 100 - ((al-50)/50*5)
        else if (al <= 200) print 95 - ((al-100)/100*10)
        else if (al <= 500) print 85 - ((al-200)/300*25)
        else if (al <= 1000) print 60 - ((al-500)/500*30)
        else print 30*(2000-al)/1000
    }')

    final_score=$(awk -v sr=$success_rate -v ls=$latency_score 'BEGIN {
        fs = (sr*0.4)+(ls*0.6)
        if (sr < 60) fs = fs * 0.5
        print int(fs)
    }')

    if [ "$QUIET_MODE" = false ]; then
        printf "%-50s | %-9.1f%% | %-11.0fms | %-10.1f\n" "$proxy" "$success_rate" "$avg_latency" "$final_score"
    else
        echo "$proxy,$final_score"
    fi

    if (( $(echo "$final_score > $best_score" | bc -l) )) || (( $(echo "$final_score == $best_score && $avg_latency < $best_latency" | bc -l) )); then
        best_score=$final_score
        best_latency=$avg_latency
        best_proxy=$proxy
    fi
done

if [ "$QUIET_MODE" = false ]; then
    echo -e "\n最快节点: $best_proxy (得分: $best_score, 延迟: ${best_latency}ms)"
fi
