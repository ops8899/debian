export DEBIAN_FRONTEND=noninteractive
cd /tmp
apt update && apt install curl -y
curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh