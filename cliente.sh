#!/bin/bash
# cliente.sh - Configuração do Cliente na LAN
# Execute: sudo bash cliente.sh

set -e

echo "=============================================="
echo "CLIENTE (LAN) - CONFIGURAÇÃO COMPLETA"
echo "=============================================="

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash cliente.sh"
    exit 1
fi

echo "[1/4] Configurando rede..."

IFACE=$(ip link show | grep -o "enp0s[0-9]" | head -1)

cat > /etc/netplan/00-installer-config.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      dhcp4: false
EOF

netplan apply
sleep 3

echo " Interface $IFACE configurada: 192.168.1.100/24"

echo "[2/4] Configurando DNS..."

systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true

rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "DNS configurado"
echo "[3/4] Instalando ferramentas de teste..."

apt update
apt install -y curl wget telnet ftp net-tools nmap

echo " Ferramentas instaladas"

echo "[4/4] Criando scripts de teste..."

cat > /root/configurar-proxy.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "CONFIGURAR PROXY NO CLIENTE"
echo "=============================================="
echo ""
echo "1. Configurar proxy temporário (sessão atual):"
echo "   export http_proxy=http://192.168.1.1:3128"
echo "   export https_proxy=http://192.168.1.1:3128"
echo ""
echo "2. Configurar proxy permanente:"
echo "   echo 'export http_proxy=http://192.168.1.1:3128' >> ~/.bashrc"
echo "   echo 'export https_proxy=http://192.168.1.1:3128' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "3. Remover proxy:"
echo "   unset http_proxy https_proxy"
echo "=============================================="
EOF

cat > /root/testar-conectividade.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTES DE CONECTIVIDADE - CLIENTE"
echo "=============================================="
echo ""
echo "1. GATEWAY (firewall):"
ping -c 2 192.168.1.1
echo ""
echo "2. INTERNET (8.8.8.8):"
ping -c 2 8.8.8.8
echo ""
echo "3. DNS (google.com):"
ping -c 2 google.com
echo ""
echo "4. SERVIDOR WEB (DMZ - 10.0.0.2):"
ping -c 2 10.0.0.2
curl -s http://10.0.0.2 | grep -o "<h1>.*</h1>"
echo ""
echo "=============================================="
EOF

cat > /root/testar-proxy.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTE DO PROXY - COM PROXY CONFIGURADO"
echo "=============================================="
echo ""

if [ -z "$http_proxy" ]; then
    echo "Proxy NÃO configurado!"
    echo "Execute: source /root/configurar-proxy.sh"
    echo ""
    echo "Configurando proxy para este teste..."
    export http_proxy=http://192.168.1.1:3128
    export https_proxy=http://192.168.1.1:3128
fi

echo "Proxy atual: $http_proxy"
echo ""

echo "1. Site PERMITIDO (google.com):"
curl -s -I http://google.com | head -1
echo ""

echo "2. Site BLOQUEADO (facebook.com):"
curl -s -I http://facebook.com 2>&1 | head -1
echo ""

echo "3. Site BLOQUEADO (youtube.com):"
curl -s -I http://youtube.com 2>&1 | head -1
echo ""

echo "4. Site BLOQUEADO (instagram.com):"
curl -s -I http://instagram.com 2>&1 | head -1
echo ""

echo "=============================================="
echo "Para ver logs no firewall:"
echo "ssh firewall 'sudo tail -f /var/log/squid/access.log'"
echo "=============================================="
EOF

cat > /root/testar-tudo.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTE COMPLETO - TRABALHO DE SEGURANCA"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_cmd() {
    if $1 >/dev/null 2>&1; then
        echo -e "${GREEN} ok $2${NC}"
    else
        echo -e "${RED} err $2${NC}"
    fi
}

test_cmd "ping -c 1 192.168.1.1" "Gateway (firewall)"
test_cmd "ping -c 1 10.0.0.2" "Servidor WEB (DMZ)"
test_cmd "ping -c 1 8.8.8.8" "Internet (IP)"
test_cmd "ping -c 1 google.com" "Internet (DNS)"
echo ""

test_cmd "curl -s http://10.0.0.2 > /dev/null" "HTTP - Servidor WEB"
curl -s http://10.0.0.2 | grep -o "<h1>.*</h1>"
echo ""

echo "3. TESTE DO PROXY:"
if [ -z "$http_proxy" ]; then
    echo -e "${YELLOW} Proxy não configurado${NC}"
    echo "Configure o proxy e teste novamente:"
    echo "  export http_proxy=http://192.168.1.1:3128"
    echo "  export https_proxy=http://192.168.1.1:3128"
    echo "  bash /root/testar-proxy.sh"
else
    echo "Proxy configurado: $http_proxy"
    if curl -s -I http://example.com 2>/dev/null | grep -q "200"; then
        echo -e "${GREEN} Site permitido (example.com) - OK${NC}"
    else
        echo -e "${RED} Site permitido (example.com) - FALHOU${NC}"
    fi
    
    if curl -s -I http://facebook.com 2>&1 | grep -q "403\|denied"; then
        echo -e "${GREEN} Site bloqueado (facebook.com) - BLOQUEADO${NC}"
    else
        echo -e "${RED} Site bloqueado (facebook.com) - NÃO BLOQUEADO${NC}"
    fi
fi
echo ""

echo "=============================================="
echo "TESTES CONCLUIDOS"
echo "=============================================="
EOF

chmod +x /root/*.sh

echo "=============================================="
echo "CLIENTE CONFIGURADO"
echo "=============================================="
echo ""
echo "IP: 192.168.1.100"
echo "Gateway: 192.168.1.1"
echo ""
echo "SCRIPTS DISPONÍVEIS:"
echo "  /root/testar-conectividade.sh  - Testar rede"
echo "  /root/configurar-proxy.sh       - Configurar proxy"
echo "  /root/testar-proxy.sh           - Testar proxy"
echo "  /root/testar-tudo.sh             - Teste completo"
echo ""
echo "1. Teste conectividade: bash /root/testar-conectividade.sh"
echo "2. Configure o proxy:"
echo "   export http_proxy=http://192.168.1.1:3128"
echo "   export https_proxy=http://192.168.1.1:3128"
echo "3. Teste o proxy: bash /root/testar-proxy.sh"
echo "4. Teste completo: bash /root/testar-tudo.sh"
echo ""
echo "=============================================="