```shell

# 导出容器
docker commit aapanel ops8899/aapanel:backup
docker save ops8899/aapanel:backup | gzip > /root/aapanel_backup.tar.gz

```