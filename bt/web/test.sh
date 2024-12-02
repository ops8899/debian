docker run --privileged --name test-web -d \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    ops8899/web
