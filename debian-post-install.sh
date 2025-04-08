#!/bin/bash

########################################################################
# Variables
########################################################################
INTERFACE=''
IPADDRESS=''
NETMASK=''
GATEWAY=''
NAMESERVER1=''
NAMESERVER2=''
DOMAIN=''
HOSTNAME=''
HOST=''
USERNAME=''
PRIVATEKEY=''
PUBLICKEY=''
PRESHAREDKEY=''


########################################################################
# Sudo
########################################################################
touch /etc/sudoers.d/$USERNAME

cat <<EOF > /etc/sudoers.d/$USERNAME
$USERNAME ALL=(ALL) NOPASSWD:ALL
EOF


########################################################################
# Bootloader
########################################################################
cat <<EOF >> /etc/grub.d/40_custom

set superusers="$USERNAME"
password_pbkdf2 $USERNAME grub.pbkdf2.sha512.10000.###################################

menuentry "Reboot" {
      reboot
}

menuentry "Shut Down" {
      halt
}
EOF

sed -i 's/CLASS="--class gnu-linux --class gnu --class os"/CLASS="--class gnu-linux --class gnu --class os --unrestricted"/' /etc/grub.d/10_linux

update-grub


########################################################################
# Network
########################################################################
sed -i -e '11,12 s/./# &/' /etc/network/interfaces

cat <<EOF > /etc/network/interfaces.d/$INTERFACE
auto $INTERFACE
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IPADDRESS
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameserver $NAMESERVER1
    dns-nameserver $NAMESERVER2
EOF

cat <<EOF >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl -p


########################################################################
# Firewall
########################################################################
sed -i -e 's/^\(ENABLED\)=.*/\1="yes"/' /etc/ufw/ufw.conf
sed -i -e 's/^\(LOGLEVEL\)=.*/\1="off"/' /etc/ufw/ufw.conf

cat <<EOF > /etc/ufw/user.rules
*filter
:ufw-user-input - [0:0]
:ufw-user-output - [0:0]
:ufw-user-forward - [0:0]
:ufw-user-limit - [0:0]
:ufw-user-limit-accept - [0:0]
### RULES ###

### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 OpenSSH - in
-A ufw-user-input -p tcp --dport 22 -j ACCEPT -m comment --comment 'dapp_OpenSSH'

### END RULES ###

COMMIT
EOF


########################################################################
# Name Resolution
########################################################################
cat <<EOF > /etc/resolv.conf
domain $DOMAIN
search $DOMAIN
nameserver $NAMESERVER1
nameserver $NAMESERVER2
EOF


########################################################################
# Hostname
########################################################################
cat <<EOF > /etc/hostname
$HOSTNAME
EOF

cat <<EOF > /etc/hosts
127.0.0.1   localhost
127.0.1.1   $HOSTNAME   $HOST
EOF

########################################################################
# Repositories
########################################################################
#cat <<EOF > /etc/apt/sources.list
## See /etc/apt/sources.list.d/bookworm.sources
#EOF
#
#cat <<EOF > /etc/apt/sources.list.d/bookworm.sources
#Types: deb deb-src
#URIs: https://deb.debian.org/debian
#Suites: bookworm bookworm-updates bookworm-backports
#Components: main contrib non-free non-free-firmware
#Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
#
#Types: deb deb-src
#URIs: https://security.debian.org/debian-security
#Suites: bookworm-security
#Components: main contrib non-free non-free-firmware
#Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
#EOF

cat <<EOF > /etc/apt/sources.list
# See /etc/apt/sources.list.d/trixie.sources
EOF

cat <<EOF > /etc/apt/sources.list.d/trixie.sources
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security/
Suites: trixie-security/updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF


########################################################################
# Software
########################################################################
apt-get install -y \
btop \
chrony \
curl \
git \
gpg \
htop \
tree \
unattended-upgrades \
vim \
wireguard-tools \
zram-tools \
zsh


########################################################################
# NTP Synchronization
########################################################################
systemctl enable --now chrony
timedatectl set-timezone Europe/Stockholm --adjust-system-clock
timedatectl set-ntp yes


########################################################################
# Automatic Updates
########################################################################
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove

cp /dev/null /etc/apt/apt.conf.d/50unattended-upgrades
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename}-updates";
        "origin=Debian,codename=${distro_codename}-proposed-updates";
        "origin=Debian,codename=${distro_codename},label=Debian";
        "origin=Debian,codename=${distro_codename},label=Debian-Security";
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

systemctl restart unattended-upgrades.service

cp /dev/null /etc/apt/apt.conf.d/20auto-upgrades
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF


########################################################################
# WireGuard
########################################################################
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address=###################################
ListenPort=51820
PrivateKey=$PRIVATEKEY
PostUp=iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown=iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey=$PUBLICKEY
PresharedKey=$PRESHAREDKEY
AllowedIPs=###################################
EOF

chmod 0600 /etc/wireguard/wg0.conf


########################################################################
# Cockpit
########################################################################
#cat <<EOF > /etc/cockpit/cockpit.conf
#[WebService]
#    AllowMultiHost=true
#[Session]
#    WarnBeforeConnecting=false
#EOF

#systemctl enable --now cockpit.socket


########################################################################
# SSH
########################################################################
mkdir /home/$USERNAME/.ssh/

cat <<EOF >/home/$USERNAME/.ssh/authorized_keys
ecdsa-sha2-nistp521 ###################################

EOF

cat <<EOF > /home/$USERNAME/.ssh/config
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ecdsa
    Port 22
    User $USERNAME
    
Host macbook-air
    HostName 10.1.1.100
EOF

ssh-keygen -t ecdsa -b 521 -f /home/$USERNAME/.ssh/id_ecdsa -P "###################################"

chmod 0700 /home/$USERNAME/.ssh/
chmod 0600 /home/$USERNAME/.ssh/authorized_keys
chmod 0600 /home/$USERNAME/.ssh/config
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh/

cat <<EOF >> /etc/ssh/sshd_config.d/60-local.conf
HostKey /etc/ssh/ssh_host_ecdsa_key
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
EOF

chmod 0600 /etc/ssh/sshd_config.d/60-local.conf


########################################################################
# Zram
########################################################################
echo "ALGO=zstd\nPERCENT=50\nPRIORITY=100" | sudo tee -a /etc/default/zramswap
sudo service zramswap reload


########################################################################
# Console
########################################################################
cat <<EOF > /etc/issue
\S
Kernel \r on an \m
\d \t
$INTERFACE: \4{$INTERFACE}

EOF

sed -i -e 's/^\(CODESET\)=.*/\1="Lat15"/' /etc/default/console-setup
sed -i -e 's/^\(FONTFACE\)=.*/\1="TerminusBold"/' /etc/default/console-setup
sed -i -e 's/^\(FONTSIZE\)=.*/\1="10x18"/' /etc/default/console-setup
sed -i -e 's/^\(XKBVARIANT\)=.*/\1="mac"/' /etc/default/keyboard


########################################################################
# Desktop
########################################################################
#apt-get install -y kde-plasma-desktop
#systemctl set-default graphical.target
