```bash
#!/bin/bash

echo "Configurando cliente..."

apt update
apt install -y curl wget dnsutils net-tools

IF=enp0s3

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

echo "Configurando proxy..."

cat >> /etc/environment <<EOF
http_proxy=http://10.0.3.1:3128
https_proxy=http://10.0.3.1:3128
ftp_proxy=http://10.0.3.1:3128
no_proxy=localhost,127.0.0.1,10.0.0.0/8
HTTP_PROXY=http://10.0.3.1:3128
HTTPS_PROXY=http://10.0.3.1:3128
FTP_PROXY=http://10.0.3.1:3128
NO_PROXY=localhost,127.0.0.1,10.0.0.0/8
EOF

cat > /etc/apt/apt.conf.d/95-proxy <<EOF
Acquire::http::Proxy "http://10.0.3.1:3128";
Acquire::https::Proxy "http://10.0.3.1:3128";
EOF

cat > ~/teste.sh <<EOF
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n\033[1mTESTES DE CONECTIVIDADE\033[0m\n"

echo -n "PING FIREWALL (10.0.3.1): "
if ping -c 2 -W 2 10.0.3.1 > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FALHOU${NC}"
fi

echo -n "PING SERVIDOR (10.0.4.10): "
if ping -c 2 -W 2 10.0.4.10 > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FALHOU${NC}"
fi

echo -n "PING INTERNET (8.8.8.8): "
if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FALHOU${NC}"
fi

echo -e "\n\033[1mTESTES WEB\033[0m\n"

echo "TESTE SERVIDOR LOCAL (10.0.4.10):"
curl -I --connect-timeout 5 http://10.0.4.10 2>/dev/null | head -n 1

echo -e "\nTESTE SITE PERMITIDO (google.com):"
curl -I --connect-timeout 5 http://google.com 2>/dev/null | head -n 1

echo -e "\nTESTE SITE BLOQUEADO (facebook.com):"
curl -I --connect-timeout 5 http://facebook.com 2>/dev/null | head -n 1

echo -e "\n\033[1mINFORMAÇÕES DE REDE\033[0m\n"
echo "IP: \$(ip -4 addr show $IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
echo "Gateway: \$(ip route | grep default | awk '{print \$3}')"
echo "DNS: \$(cat /etc/resolv.conf | grep nameserver | awk '{print \$2}')"
EOF

chmod +x ~/teste.sh

echo "Configurando aliases..."
cat >> ~/.bashrc <<EOF
alias testar='~/teste.sh'
alias ip='ip -c addr'
alias proxytest='curl -I http://google.com'
EOF

echo "Configurando ambiente..."
source ~/.bashrc

echo ""
echo "===================================="
echo "Cliente configurado com sucesso!"
echo "===================================="
echo ""
echo "IP: 10.0.3.10/24"
echo "Gateway: 10.0.3.1"
echo "Proxy: http://10.0.3.1:3128"
echo ""
echo "Comandos uteis:"
echo "  testar     - Executar testes de conectividade"
echo "  ip         - Ver configuração de IP"
echo ""
echo "Execute './teste.sh' para testar a conexão"
echo "===================================="
```