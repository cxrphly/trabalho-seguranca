#!/bin/bash

echo "CONFIGURANDO FIREWALL..."

apt update
apt install -y iptables squid iptables-persistent net-tools curl

echo "Ativando roteamento..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

WAN=enp0s3
LAN=enp0s8
DMZ=enp0s9

echo "Configurando rede..."

cat > /etc/netplan/01-firewall.yaml <<EOF
network:
 version: 2
 renderer: networkd
 ethernets:
  $WAN:
   dhcp4: true
  $LAN:
   addresses:
    - 10.0.3.1/24
  $DMZ:
   addresses:
    - 10.0.4.1/24
EOF

netplan apply
sleep 5

echo "Limpando regras..."

iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

echo "Loopback"

iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

echo "Conexões estabelecidas"

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "Firewall próprio"

iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

echo "LAN CLIENTE"

iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 53 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 21 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 25 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p icmp -j ACCEPT

echo "DMZ"

iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -d 10.0.4.10 -p icmp -j ACCEPT

echo "Servidor DMZ internet"

iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p udp --dport 53 -j ACCEPT

echo "NAT"

iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o $WAN -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.4.0/24 -o $WAN -j MASQUERADE

echo "DNAT servidor web"

iptables -t nat -A PREROUTING -i $WAN -p tcp --dport 80 -j DNAT --to 10.0.4.10
iptables -t nat -A PREROUTING -i $WAN -p tcp --dport 443 -j DNAT --to 10.0.4.10

echo "Configurando Squid..."

cat > /etc/squid/blacklist.txt <<EOF
.facebook.com
.youtube.com
.netflix.com
.instagram.com
.tiktok.com
EOF

cat > /etc/squid/squid.conf <<EOF

http_port 3128

acl rede_cliente src 10.0.3.0/24
acl bloqueados dstdomain "/etc/squid/blacklist.txt"

http_access deny bloqueados
http_access allow rede_cliente
http_access deny all

cache_mem 256 MB

access_log /var/log/squid/access.log

visible_hostname firewall

dns_nameservers 8.8.8.8 8.8.4.4
EOF

systemctl restart squid
systemctl enable squid

netfilter-persistent save

echo "FIREWALL CONFIGURADO"