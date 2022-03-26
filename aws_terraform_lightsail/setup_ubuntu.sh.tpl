#!/usr/bin/env bash
# -*- coding: utf-8 -*-
USERNAME=${username}

# install tmux zsh mosh
apt-get update
apt-get install -y \
tmux \
zsh \
mosh \
tree \
ipcalc \
htop

echo "Install Docker"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker

echo "Install Docker Compose"
curl \
-L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
-o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "Allow User to use Docker without sudo"
usermod -aG docker "$USERNAME"  # username might vary

pushd /home/$USERNAME/ 
su "$USERNAME" -c \
"git clone https://github.com/Jeonkwan/trojan-go-caddy.git"
su "$USERNAME" -c \
"curl -s \"https://get.sdkman.io\" | bash"
su "$USERNAME" -c \
"sh -c \"$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
popd

# enable ECN for vxtran performance boost
echo "net.ipv4.tcp_ecn_fallback = 1" >> /etc/sysctl.conf
# apply changes without reboot
sysctl -p
