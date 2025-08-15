cat > /etc/logrotate.d/juicefs <<'EOF'
/var/log/juicefs.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# 默认安装到 /usr/local/bin
curl -sSL https://d.juicefs.com/install | sh -
