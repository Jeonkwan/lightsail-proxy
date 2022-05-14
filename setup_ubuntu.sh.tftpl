#!/usr/bin/env bash

USERNAME="${username}"
DOMAIN="${domain_name}"
SUBDOMAIN="${subdomain_name}"
PUBLIC_IP="${public_ip}"
NC_DDNS_PASS="${namecheap_ddns_password}"
TROJAN_GO_PASS="${trojan_go_password}"

BASE_DIR=$(pwd)

# minimum setup
apt-get update
apt-get install -y \
tmux \
mosh \
tree \
uuid \
zip \
unzip

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

cd /opt
git clone "https://github.com/Jeonkwan/trojan-go-caddy.git"
cd trojan-go-caddy
chmod +x *.sh
touch init.log
echo "Update namecheap record"
printf "$DOMAIN\n$SUBDOMAIN\n$PUBLIC_IP\n$NC_DDNS_PASS" | ./configure_namecheap_dns.sh >> init.log
echo "Configure Trojan go"
printf "$TROJAN_GO_PASS\n$SUBDOMAIN.$DOMAIN" | ./configure_trojan-go.sh >> init.log
tree ./ >> init.log
echo "Run Trojan go"
docker-compose -f ./docker-compose_trojan-go.yml up &
cd $BASE_DIR

# enable ECN for vxtran performance boost
echo "net.ipv4.tcp_ecn_fallback = 1" >> /etc/sysctl.conf
# apply changes without reboot
sysctl -p

# extra setup
apt-get install -y \
zsh \
ipcalc \
htop

cd /home/$USERNAME/
su "$USERNAME" \
-c "curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o ohmyzsh_install.sh && chmod +x ohmyzsh_install.sh"
su "$USERNAME" \
-c "sh -c "./ohmyzsh_install.sh""
chsh "$USERNAME" -s /usr/bin/zsh

# su "$USERNAME" \
# -c "curl -s \"https://get.sdkman.io\" | bash"
# su "$USERNAME" \
# -c "echo \"source ~/.sdkman/bin/sdkman-init.sh\" >> ./.bashrc"
# su "$USERNAME" \
# -c "echo \"source ~/.sdkman/bin/sdkman-init.sh\" >> ./.zshrc"
# cd $BASE_DIR
