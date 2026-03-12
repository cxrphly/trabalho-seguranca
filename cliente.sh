#!/bin/bash

set -e

echo "================================="
echo "CONFIGURANDO CLIENTE (LAN)"
echo "================================="

sleep 2

echo "Atualizando pacotes..."
apt update

echo "Instalando ferramentas..."
apt install -y curl wget dnsutils net-tools

IF=enp0s3

echo "Configurando rede..."

cat > /etc/netplan/01-client.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF:
      addresses:
        - 10.0.3.10/24
      routes:
        - to: default
          via: 10.0.3.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

netplan apply
sleep 3

echo "Rede configurada."

echo "Configurando proxy do sistema..."

cat > /etc/environment <<EOF
http_proxy=http://10.0.3.1:3128
https_proxy=http://10.0.3.1:3128
ftp_proxy=http://10.0.3.1:3128
no_proxy=localhost,127.0.0.1,10.0.0.0/8
HTTP_PROXY=http://10.0.3.1:3128
HTTPS_PROXY=http://10.0.3.1:3128
FTP_PROXY=http://10.0.3.1:3128
NO_PROXY=localhost,127.0.0.1,10.0.0.0/8
EOF

echo "Configurando proxy do APT..."

cat > /etc/apt/apt.conf.d/95-proxy <<EOF
Acquire::http::Proxy "http://10.0.3.1:3128";
Acquire::https::Proxy "http://10.0.3.1:3128";
EOF

echo "Criando script de testes..."

cat > ~/teste.sh <<EOF
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\nTESTES DE CONECTIVIDADE\n"

echo -n "PING FIREWALL (10.0.3.1): "
ping -c 2 10.0.3.1 > /dev/null && echo -e "\${GREEN}OK\${NC}" || echo -e "\${RED}FALHOU\${NC}"

echo -n "PING SERVIDOR (10.0.4.10): "
ping -c 2 10.0.4.10 > /dev/null && echo -e "\${GREEN}OK\${NC}" || echo -e "\${RED}FALHOU\${NC}"

echo -n "PING INTERNET (8.8.8.8): "
ping -c 2 8.8.8.8 > /dev/null && echo -e "\${GREEN}OK\${NC}" || echo -e "\${RED}FALHOU\${NC}"

echo -e "\nTESTES WEB\n"

echo "Servidor DMZ:"
curl -I http://10.0.4.10 2>/dev/null | head -n 1

echo "Site permitido (Google):"
curl -I http://google.com 2>/dev/null | head -n 1

echo "Site bloqueado (Facebook):"
curl -I http://facebook.com 2>/dev/null | head -n 1

echo -e "\nINFORMACOES DE REDE\n"

echo "IP: \$(hostname -I)"
echo "Gateway: \$(ip route | grep default | awk '{print \$3}')"
echo "DNS:"
cat /etc/resolv.conf | grep nameserver

EOF

chmod +x ~/teste.sh

echo "Configurando aliases..."

cat >> ~/.bashrc <<EOF

alias testar='~/teste.sh'
alias ip='ip -c addr'
alias proxytest='curl -I http://google.com'

EOF

echo ""
echo "================================="
echo "CLIENTE CONFIGURADO"
echo "================================="
echo ""
echo "IP: 10.0.3.10"
echo "Gateway: 10.0.3.1"
echo "Proxy: http://10.0.3.1:3128"
echo ""
echo "Execute:"
echo "testar"
echo ""
echo "================================="