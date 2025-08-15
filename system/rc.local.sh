#!/bin/bash

#创建缺失的 /etc/rc.local

cat <<EOF >/etc/rc.local
#!/bin/sh -e
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.

iptables -A FORWARD -j ACCEPT

exit 0
EOF

chmod +x /etc/rc.local

#创建缺失的 rc.local 服务
cat <<EOF >/etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF

#启用并立即启动服务
systemctl enable --now rc-local
