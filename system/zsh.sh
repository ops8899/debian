#!/bin/bash

# 检查并安装 oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "安装 oh-my-zsh..."
    sh -c "$(curl -fsSL --retry 5 https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    chsh -s $(which zsh) root
else
    echo "oh-my-zsh 已安装"
fi

KEY_BINDINGS=$(cat <<'EOF'
bindkey "\e[1~" beginning-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[5~" beginning-of-history
bindkey "\e[6~" end-of-history
bindkey "\e[8~" end-of-line
bindkey "\e[7~" beginning-of-line
bindkey "\eOH" beginning-of-line
bindkey "\eOF" end-of-line
bindkey "\e[H" beginning-of-line
bindkey "\e[F" end-of-line
bindkey '^i' expand-or-complete-prefix
bindkey -s "^[Op" "0"
bindkey -s "^[On" "."
bindkey -s "^[OM" "^M"
bindkey -s "^[Oq" "1"
bindkey -s "^[Or" "2"
bindkey -s "^[Os" "3"
bindkey -s "^[Ot" "4"
bindkey -s "^[Ou" "5"
bindkey -s "^[Ov" "6"
bindkey -s "^[Ow" "7"
bindkey -s "^[Ox" "8"
bindkey -s "^[Oy" "9"
bindkey -s "^[Ol" "+"
bindkey -s "^[Om" "-"
bindkey -s "^[Oj" "*"
bindkey -s "^[Oo" "/"
EOF
)

# 将键绑定添加到 .zshrc 中
if ! grep -q 'bindkey "\\e\[1~" beginning-of-line' ~/.zshrc; then
  echo "$KEY_BINDINGS" >> ~/.zshrc
  echo "键绑定已添加到 ~/.zshrc"
else
  echo "键绑定已存在于 ~/.zshrc"
fi

# 修改.bashrc
if ! grep -q 'source ~/.bashrc' ~/.zshrc; then
    echo 'source ~/.bashrc' >> ~/.zshrc
fi

sed -i '/DISABLE_AUTO_UPDATE=true/d' ~/.zshrc && sed -i '1i export DISABLE_AUTO_UPDATE=true' ~/.zshrc
sed -i '/外网IP.*国内节点/d' ~/.zshrc && \
sed -i '2i echo "外网IP1(国内节点): $(timeout 3 curl -s ip.3322.net 2>/dev/null || echo \"获取失败\") | IP2(国外节点): $(timeout 3 curl -s ipinfo.io/ip 2>/dev/null || echo \"获取失败\")" &' ~/.zshrc
sed -i '/网卡信息:/d; /ip.*addr.*show/d; /ip -4 addr show/d; /echo.*网关/d' ~/.zshrc && sed -i '3i echo "网卡信息:"; ip addr show | grep -E "^[0-9]+:|inet " | grep -v "127.0.0.1" | sed "N;s/\\n/ /" | awk '\''{print "  " substr($2,1,length($2)-1) ": " $4}'\''; echo "  网关: $(ip route show default | awk '\''{print $3}'\'' | head -1)"' ~/.zshrc

