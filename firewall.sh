#!/bin/bash

echo "=== Configurando Firewall ==="

echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

WAN_IF=$(ip link | grep -E "enp0s3|ens3" | cut -d: -f2 | tr -d ' ' | head -1)
LAN_IF=$(ip link | grep -E "enp0s8|ens8" | cut -d: -f2 | tr -d ' ' | head -1)
DMZ_IF=$(ip link | grep -E "enp0s9|ens9" | cut -d: -f2 | tr -d ' ' | head -1)

[ -z "$WAN_IF" ] && WAN_IF="enp0s3"
[ -z "$LAN_IF" ] && LAN_IF="enp0s8"
[ -z "$DMZ_IF" ] && DMZ_IF="enp0s9"

echo "Interfaces: WAN=$WAN_IF, LAN=$LAN_IF, DMZ=$DMZ_IF"

cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $WAN_IF:
      dhcp4: true
    $LAN_IF:
      addresses:
        - 10.0.3.1/24
    $DMZ_IF:
      addresses:
        - 10.0.4.1/24
EOF

netplan apply
sleep 5

iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

iptables -A FORWARD -p tcp -d 10.0.4.10 --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -d 10.0.4.10 --dport 443 -j ACCEPT
iptables -A FORWARD -p icmp -d 10.0.4.10 --icmp-type echo-request -j ACCEPT

iptables -A FORWARD -p tcp -s 10.0.3.0/24 --dport 22 -j ACCEPT
iptables -A FORWARD -p udp -s 10.0.3.0/24 --dport 53 -j ACCEPT
iptables -A FORWARD -p tcp -s 10.0.3.0/24 --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -s 10.0.3.0/24 --dport 443 -j ACCEPT
iptables -A FORWARD -p tcp -s 10.0.3.0/24 --dport 21 -j ACCEPT
iptables -A FORWARD -p tcp -s 10.0.3.0/24 --dport 25 -j ACCEPT
iptables -A FORWARD -p icmp -s 10.0.3.0/24 --icmp-type echo-request -j ACCEPT

iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o $WAN_IF -j MASQUERADE
iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 80 -j DNAT --to-destination 10.0.4.10:80
iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 443 -j DNAT --to-destination 10.0.4.10:443

apt-get update
apt-get install -y squid

cat > /etc/squid/squid.conf << EOF
http_port 3128
acl rede_cliente src 10.0.3.0/24
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 21
acl Safe_ports port 22
acl Safe_ports port 25
acl Safe_ports port 53
acl sites_bloqueados dstdomain "/etc/squid/blacklist.txt"
http_access allow rede_cliente !sites_bloqueados
http_access deny sites_bloqueados
http_access deny !Safe_ports
http_access deny all
access_log /var/log/squid/access.log squid
cache_mem 128 MB
cache_dir ufs /var/spool/squid 100 16 256
dns_nameservers 8.8.8.8 8.8.4.4
visible_hostname firewall.quixada.local
EOF

cat > /etc/squid/blacklist.txt << EOF
.facebook.com
.youtube.com
.instagram.com
.tiktok.com
.twitter.com
.netflix.com
.spotify.com
.twitch.tv
EOF

systemctl restart squid
systemctl enable squid

apt-get install -y iptables-persistent
netfilter-persistent save

echo "Firewall configurado. Proxy em 10.0.3.1:3128"