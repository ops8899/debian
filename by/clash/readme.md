实际故障检测机制


url: http://www.gstatic.com/generate_204
interval: 30
timeout: 3000
max-failed-times: 1

即使检测间隔是 300 秒，实际故障转移是实时的
当一个请求失败时，Clash 会立即触发检测，不会等待下一个检测周期
300 秒间隔只是用于常规的"预防性"检查
