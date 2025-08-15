

curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
bash ./debi.sh --ustc --no-install-recommends --install 'sudo curl git vim htop iotop ncdu' --no-upgrade --static-ipv4 --grub-timeout 1 --timezone Asia/Shanghai --network-console --ethx --bbr --ssh-port 61789 --user root --password Hi..8899@@ --hostname repo-us


curl -fLO https://raw.githubusercontent.com/bohanyang/debi/master/debi.sh
bash ./debi.sh --no-install-recommends --install 'sudo curl git vim htop iotop ncdu' --no-upgrade --static-ipv4 --grub-timeout 1 --timezone Asia/Shanghai --network-console --ethx --bbr --ssh-port 61789 --user root --password Hi..8899@@ --hostname repo-us



hostnamectl set-hostname new-hostname


reboot