umount /mnt/alist
rclone mount alist:/ /mnt/alist \
  --vfs-cache-mode full \
  --vfs-cache-max-size 5G \
  --vfs-cache-max-age 24h \
  --allow-other \
  --allow-non-empty \
  --daemon