#!/bin/bash
# firewall.sh - Configuração completa do Firewall
# Execute: sudo bash firewall.sh

set -e

echo "=============================================="
echo "FIREWALL/ROTEADOR - CONFIGURAÇÃO COMPLETA"
echo "=============================================="

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash firewall.sh"
    exit 1
fi

echo "[1/8] Configurando interfaces de rede..."

IF_NAT=$(ip link show | grep -o "enp0s3" | head -1)
IF_LAN=$(ip link show | grep -o "enp0s8" | head -1)
IF_DMZ=$(ip link show | grep -o "enp0s9" | head -1)

if [ -z "$IF_NAT" ]; then IF_NAT="enp0s3"; fi
if [ -z "$IF_LAN" ]; then IF_LAN="enp0s8"; fi
if [ -z "$IF_DMZ" ]; then IF_DMZ="enp0s9"; fi

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

echo "  NAT: $IF_NAT (DHCP)"
echo "  LAN: $IF_LAN (192.168.1.1/24)"
echo "  DMZ: $IF_DMZ (10.0.0.1/24)"

echo "[2/8] Ativando roteamento IP..."

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo " Roteamento ativado"


echo "[3/8] Instalando pacotes necessários..."

apt update
apt install -y squid iptables-persistent net-tools curl wget

echo "  Pacotes instalados"

# ==============================================
# 4. CONFIGURAR SQUID (PROXY EXPLÍCITO)
# ==============================================
echo "[4/8] Configurando Squid (proxy explícito)..."

systemctl stop squid

rm -rf /var/spool/squid/*
rm -rf /var/log/squid/*
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
.uol.com.br
EOF

cat > /etc/squid/squid.conf << 'EOF'
http_port 3128
acl rede_interna src 192.168.1.0/24
acl dmz src 10.0.0.0/24
acl localhost src 127.0.0.1/32
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT
acl blacklist dstdomain "/etc/squid/blacklist.txt"

http_access deny blacklist
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow rede_interna
http_access allow dmz
http_access deny all

cache_mem 8 MB
cache_dir ufs /var/spool/squid 100 16 256
maximum_object_size 4 MB
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

visible_hostname firewall-tp1
EOF

squid -k parse || { echo " Erro na configuração do Squid"; exit 1; }

squid -z

systemctl start squid
systemctl enable squid

echo " Squid configurado (porta 3128)"


echo "[5/8] Configurando iptables (firewall)..."

iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 3128 -j ACCEPT

iptables -A FORWARD -d 10.0.0.2 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -d 10.0.0.2 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -j ACCEPT

iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 21 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 20 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 1024:1048 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -s 192.168.1.0/24 -p icmp --icmp-type echo-request -j ACCEPT

iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o $IF_NAT -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o $IF_NAT -j MASQUERADE

iptables -t nat -A PREROUTING -i $IF_NAT -p tcp --dport 80 -j DNAT --to-destination 10.0.0.2:80
iptables -t nat -A PREROUTING -i $IF_NAT -p tcp --dport 443 -j DNAT --to-destination 10.0.0.2:443

netfilter-persistent save

echo " iptables configurado"

echo "[6/8] Criando scripts de verificação..."

cat > /root/verificar-firewall.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "VERIFICAÇÃO DO FIREWALL"
echo "=============================================="
echo ""
echo "1. ROTEAMENTO:"
cat /proc/sys/net/ipv4/ip_forward
echo ""
echo "2. INTERFACES:"
ip a | grep -E "enp0s|inet" | grep -v inet6
echo ""
echo "3. STATUS DO SQUID:"
systemctl status squid --no-pager | grep Active
echo ""
echo "4. REGRAS IPTABLES (FORWARD):"
iptables -L FORWARD -v -n | head -10
echo ""
echo "5. REGRAS NAT:"
iptables -t nat -L -v -n | head -10
echo ""
echo "6. BLACKLIST (primeiros 5):"
head -5 /etc/squid/blacklist.txt
echo ""
echo "=============================================="
EOF

chmod +x /root/verificar-firewall.sh


echo "[7/8] Configuração concluida"
echo "=============================================="
echo "FIREWALL CONFIGURADO"
echo "=============================================="
echo ""
echo "ACESSOS:"
echo "  LAN: 192.168.1.1/24"
echo "  DMZ: 10.0.0.1/24"
echo "  Squid: porta 3128"
echo ""
echo "  Verificar firewall: /root/verificar-firewall.sh"
echo "  Ver logs do squid: tail -f /var/log/squid/access.log"
echo "  Ver regras iptables: iptables -L -v -n"
echo ""
echo "=============================================="