#!/bin/bash

########################################################################
# Variables
########################################################################
INTERFACE=''
TYPE=''
METHOD=''
UUID=''
IPADDRESS=''
NETMASK=''
GATEWAY=''
NAMESERVER1=''
NAMESERVER2=''
DOMAIN=''
ZONE='home'
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

menuentry "Reboot" {
      reboot
}

menuentry "Shut Down" {
      halt
}
EOF

grub2-mkconfig -o /boot/grub2/grub.cfg


########################################################################
# Network
########################################################################
cat <<EOF > /etc/NetworkManager/system-connections/$INTERFACE.nmconnection
[connection]
id=$INTERFACE
uuid=$UUID
type=$TYPE
interface-name=$INTERFACE

[ethernet]

[ipv4]
address1=$IPADDRESS/$NETMASK,$GATEWAY
dns=$NAMESERVER1;$NAMESERVER2
dns-search=$DOMAIN
method=$METHOD

[ipv6]
addr-gen-mode=default
method=disabled

[proxy]
EOF


########################################################################
# Firewall
########################################################################
firewall-offline-cmd --set-default-zone=$ZONE
firewall-offline-cmd --zone=$ZONE --add-service=cockpit
firewall-offline-cmd --zone=$ZONE --add-service=ssh
firewall-offline-cmd --zone=$ZONE --add-service=wireguard


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
# Software
########################################################################
sudo rm /etc/yum.repos.d/fedora-cisco-openh264.repo

cat <<EOF > /etc/dnf/dnf.conf
[main]
max_parallel_downloads=20
fastestmirror=True
EOF

dnf install -y \
btop \
cockpit \
cockpit-files \
cockpit-podman \
fastfetch \
fzf \
git \
gpg \
htop \
nano \
nmap \
podman \
vim \
wireguard-tools \
zsh


########################################################################
# Automatic Updates
########################################################################
dnf -y update
dnf -y upgrade
dnf -y autoremove

cat <<EOF > /etc/dnf/dnf5-plugins/automatic.conf
[commands]
upgrade_type = security
[commands]
apply_updates = yes
[commands]
reboot = when-needed
EOF

systemctl enable --now dnf-automatic.timer


########################################################################
# Multipath storage
########################################################################
#mpathconf --enable --with_multipathd y
#systemctl start multipathd.service


########################################################################
# WireGuard
########################################################################
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address=#############################
ListenPort=51820
PrivateKey=$PRIVATEKEY
PostUp=iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown=iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey=$PUBLICKEY
PresharedKey=$PRESHAREDKEY
AllowedIPs=#############################
EOF

chmod 0600 /etc/wireguard/wg0.conf


########################################################################
# Cockpit
########################################################################
cat <<EOF > /etc/cockpit/cockpit.conf
[WebService]
    AllowMultiHost=true
[Session]
    WarnBeforeConnecting=false
EOF

systemctl enable --now cockpit.socket


########################################################################
# SSH
########################################################################
cat <<EOF > /home/$USERNAME/.ssh/config
Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ecdsa
    Port 22
    User $USERNAME
    
Host macbook-air
    HostName 10.1.1.100
EOF

ssh-keygen -t ecdsa -b 521 -f /home/$USERNAME/.ssh/id_ecdsa -P "#############################"

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
# Podman
########################################################################
systemctl enable --now podman.socket
systemctl enable --now podman.service
systemctl enable --now podman-auto-update.service
systemctl enable --now podman-auto-update.timer
systemctl enable --now podman-clean-transient.service
systemctl enable --now podman-restart.service
loginctl enable-linger $USERNAME


########################################################################
# Console
########################################################################
cat <<EOF > /etc/issue
\S
Kernel \r on an \m
\d \t
$INTERFACE: \4{$INTERFACE}
EOF

sed -i -e 's/^\(KEYMAP\)=.*/\1="gb-mac"/' /etc/vconsole.conf
sed -i -e 's/^\(FONT\)=.*/\1="ter-v18b"/' /etc/vconsole.conf
sed -i -e '$aVARIANT="Server Edition"' /etc/os-release
sed -i -e '$aVARIANT_ID=server' /etc/os-release


########################################################################
# Desktop
########################################################################
#dnf install -y @kde-desktop
#systemctl set-default graphical.target
