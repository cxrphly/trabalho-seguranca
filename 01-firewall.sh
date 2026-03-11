#!/bin/bash

set -e 
echo "=============================================="
echo "TRABALHO PRÁTICO 1 - SEGURANÇA DA INFORMAÇÃO"
echo "FIREWALL/ROTEADOR - Configuração Automática"
echo "=============================================="
echo ""

echo "[1/8] Verificando pré-requisitos..."

if [ "$EUID" -ne 0 ]; then 
    echo "Execute como root: sudo bash 01-firewall.sh"
    exit 1
fi
INTERFACES=$(ip link show | grep -o "enp0s[0-9]" | sort -u)
echo "Interfaces encontradas: $INTERFACES"

echo "[2/8] Limpando configurações existentes..."

iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

systemctl stop squid 2>/dev/null || true
systemctl disable squid 2>/dev/null || true

rm -rf /etc/squid/squid.conf
rm -rf /etc/squid/blacklist.txt
rm -rf /var/spool/squid/*
rm -rf /var/log/squid/*

echo "[3/8] Configurando interfaces de rede..."

IF_NAT="enp0s3"
IF_LAN="enp0s8"  
IF_DMZ="enp0s9"

cat > /etc/netplan/00-installer-config.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF_NAT:
      dhcp4: true
    $IF_LAN:
      addresses:
        - 192.168.1.1/24
    $IF_DMZ:
      addresses:
        - 10.0.0.1/24
EOF

netplan apply
sleep 3

echo "  ✓ NAT: $IF_NAT (DHCP)"
echo "  ✓ LAN: $IF_LAN (192.168.1.1/24)"
echo "  ✓ DMZ: $IF_DMZ (10.0.0.1/24)"

echo "[4/8] Ativando roteamento IP..."

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "  ✓ Roteamento ativado"

echo "[5/8] Instalando pacotes necessários..."

apt update
apt install -y squid iptables-persistent net-tools tcpdump curl wget

echo "  ✓ Pacotes instalados"


echo "[6/8] Configurando Squid (Proxy)..."

mkdir -p /var/spool/squid
mkdir -p /var/log/squid
chown -R proxy:proxy /var/spool/squid
chown -R proxy:proxy /var/log/squid

cat > /etc/squid/blacklist.txt << 'EOF'
# Redes Sociais
.facebook.com
.instagram.com
.twitter.com
.tiktok.com

# Streaming
.youtube.com
.netflix.com
.spotify.com
.twitch.tv

# Outros
.whatsapp.com
.globo.com
EOF

cat > /etc/squid/squid.conf << 'EOF'
# === PROXY TRANSPARENTE ===
http_port 3128 intercept

# ACLs BÁSICAS
acl rede_interna src 192.168.1.0/24
acl dmz src 10.0.0.0/24
acl localhost src 127.0.0.1/32

# PORTAS SEGURAS
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # portas altas
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

# BLACKLIST
acl blacklist dstdomain "/etc/squid/blacklist.txt"

# REGRAS DE ACESSO
http_access deny blacklist
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow rede_interna
http_access allow dmz
http_access deny all

# CACHE
cache_mem 8 MB
cache_dir ufs /var/spool/squid 100 16 256
maximum_object_size 4 MB

# LOGS
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log none

# CONFIGURAÇÕES ADICIONAIS
via off
forwarded_for off
visible_hostname firewall-trabalho
EOF

squid -k parse || { echo "erro na configuração do Squid"; exit 1; }
squid -z
systemctl start squid
systemctl enable squid

echo "  Squid configurado e rodando"


echo "[7/8] Configurando iptables (firewall)..."
iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "  Regras para o firewall"
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT

echo "  Regras para DMZ"
iptables -A FORWARD -d 10.0.0.2 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -d 10.0.0.2 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -j ACCEPT
echo "  Regras para LAN"
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 21 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 20 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 1024:1048 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT

echo "Configurando NAT"
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o $IF_NAT -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o $IF_NAT -j MASQUERADE

iptables -t nat -A PREROUTING -i $IF_NAT -p tcp --dport 80 -j DNAT --to-destination 10.0.0.2:80
iptables -t nat -A PREROUTING -i $IF_NAT -p tcp --dport 443 -j DNAT --to-destination 10.0.0.2:443

iptables -t nat -A PREROUTING -i $IF_LAN -s 192.168.1.0/24 -p tcp --dport 80 -j REDIRECT --to-port 3128

netfilter-persistent save

echo " iptables configurado"

echo "[8/8] Configuração concluída!"
echo "=============================================="
echo "RESUMO DAS CONFIGURAÇÕES:"
echo "=============================================="
echo ""
echo "INTERFACES DE REDE:"
ip a | grep -E "enp0s|inet" | grep -v inet6
echo ""
echo "STATUS DO SQUID:"
systemctl status squid --no-pager | grep Active
echo ""
echo "REGRAS IPTABLES (FILTER):"
iptables -L -v -n | head -10
echo ""
echo "REGRAS IPTABLES (NAT):"
iptables -t nat -L -v -n | head -10
echo ""
echo "BLACKLIST (primeiros 5):"
head -5 /etc/squid/blacklist.txt
echo ""
echo "=============================================="
echo "FIREWALL CONFIGURADO COM SUCESSO!"
echo "LAN: 192.168.1.1/24"
echo "DMZ: 10.0.0.1/24"
echo "Squid: proxy transparente na porta 3128"
echo ""
echo "PRÓXIMO PASSO: Configurar o Servidor WEB (02-servidor-web.sh)"
echo "=============================================="