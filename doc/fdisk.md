
```shell
#!/bin/bash

# 删除旧分区并创建新分区，自动回答 Y 确认删除签名
echo -e "d\nw\nn\np\n1\n\n\nY\nw" | fdisk /dev/vdb

# 强制格式化
mkfs.ext4 -F /dev/vdb1

# 挂载设置
mkdir -p /data
grep -v "/data" /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab
echo "/dev/vdb1 /data ext4 defaults 0 0" >> /etc/fstab
mount -a

df -h /data

```

```shell
# 扩容
# https://www.cnblogs.com/jrri/p/16591351.html
# 安装
apt update;apt install -y cloud-utils cloud-initramfs-growroot
# 扩容
growpart /dev/vda 1
# 查看扩容后的磁盘空间
lsblk
# 查看
df -h
# 调整
resize2fs /dev/vda1


```