#!/bin/bash
image_name="ops8899/web"

docker build -t $image_name .
docker image ls | grep $image_name
if [ -n "$1" ]; then
  docker push $image_name
fi
echo "image name: $image_name done!"