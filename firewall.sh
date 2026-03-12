#!/bin/bash

echo "=== CONFIGURACAO COMPLETA DO FIREWALL ==="
echo "Data: $(date)"
echo

# Habilitar IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Identificar interfaces
WAN_IF=$(ip link | grep -E "enp0s3|ens3" | cut -d: -f2 | tr -d ' ' | head -1)
LAN_IF=$(ip link | grep -E "enp0s8|ens8" | cut -d: -f2 | tr -d ' ' | head -1)
DMZ_IF=$(ip link | grep -E "enp0s9|ens9" | cut -d: -f2 | tr -d ' ' | head -1)

[ -z "$WAN_IF" ] && WAN_IF="enp0s3"
[ -z "$LAN_IF" ] && LAN_IF="enp0s8"
[ -z "$DMZ_IF" ] && DMZ_IF="enp0s9"

echo "Interfaces:"
echo "  WAN: $WAN_IF (Internet)"
echo "  LAN: $LAN_IF (Cliente: 10.0.3.0/24)"
echo "  DMZ: $DMZ_IF (Servidor: 10.0.4.0/24)"
echo

# Configurar IPs das interfaces
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

# LIMPAR TODAS AS REGRAS
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# POLITICA PADRAO DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# LOOPBACK
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# CONEXOES ESTABELECIDAS
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# REGRAS PARA O PROPRIO FIREWALL
iptables -A INPUT -p tcp --dport 22 -j ACCEPT           # SSH
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT  # PING
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT          # DNS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT          # DNS TCP
iptables -A OUTPUT -p udp --dport 123 -j ACCEPT         # NTP

# REGRAS PARA O SERVIDOR WEB (DMZ - 10.0.4.10)
iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 80 -j ACCEPT   # HTTP
iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 443 -j ACCEPT  # HTTPS
iptables -A FORWARD -d 10.0.4.10 -p icmp --icmp-type echo-request -j ACCEPT  # PING

# REGRAS PARA O CLIENTE (LAN - 10.0.3.10)
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 22 -j ACCEPT   # SSH
iptables -A FORWARD -s 10.0.3.10 -p udp --dport 53 -j ACCEPT   # DNS
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 53 -j ACCEPT   # DNS TCP
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 80 -j ACCEPT   # HTTP
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 443 -j ACCEPT  # HTTPS
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 21 -j ACCEPT   # FTP
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 20 -j ACCEPT   # FTP data
iptables -A FORWARD -s 10.0.3.10 -p tcp --dport 25 -j ACCEPT   # SMTP
iptables -A FORWARD -s 10.0.3.10 -p icmp --icmp-type echo-request -j ACCEPT  # PING

# NAT - SNAT (cliente para internet)
iptables -t nat -A POSTROUTING -s 10.0.3.10 -o $WAN_IF -j MASQUERADE

# NAT - DNAT (internet para servidor web)
iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 80 -j DNAT --to-destination 10.0.4.10:80
iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 443 -j DNAT --to-destination 10.0.4.10:443

# REGRAS ADICIONAIS PARA O SERVIDOR WEB ACESSAR INTERNET (PARA INSTALACAO)
iptables -t nat -A POSTROUTING -s 10.0.4.10 -o $WAN_IF -j MASQUERADE
iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p udp --dport 53 -j ACCEPT

# INSTALAR E CONFIGURAR SQUID
apt-get update
apt-get install -y squid iptables-persistent

cat > /etc/squid/squid.conf << 'EOF'
http_port 3128
acl rede_cliente src 10.0.3.10
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

cat > /etc/squid/blacklist.txt << 'EOF'
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

# SALVAR REGRAS
netfilter-persistent save

echo
echo "=== CONFIGURACAO CONCLUIDA ==="
echo
echo "RESUMO:"
echo "  Firewall IPs:"
echo "    WAN: $WAN_IF (DHCP)"
echo "    LAN: $LAN_IF - 10.0.3.1"
echo "    DMZ: $DMZ_IF - 10.0.4.1"
echo
echo "  Cliente: 10.0.3.10"
echo "  Servidor Web: 10.0.4.10"
echo "  Proxy Squid: 10.0.3.1:3128"
echo
echo "  Regras aplicadas:"
echo "    - Cliente pode acessar: SSH, DNS, HTTP/HTTPS, FTP, SMTP, PING"
echo "    - Servidor Web pode: HTTP/HTTPS (entrada) e internet (saida)"
echo "    - Firewall pode: SSH, PING, DNS"
echo