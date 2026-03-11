#!/bin/bash
set -e
echo "=============================================="
echo "CLIENTE (LAN) - Configuração Automática"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Execute como root: sudo bash 03-cliente.sh"
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
echo "  Interface $IFACE configurada: 192.168.1.100/24"
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
apt install -y curl wget telnet ftp net-tools nmap firefox
echo "Ferramentas instaladas"
echo "[4/4] Criando scripts de teste..."
cat > /home/testar-conectividade.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTES DE CONECTIVIDADE - CLIENTE LAN"
echo "=============================================="
echo ""
echo "1. GATEWAY (FIREWALL):"
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
echo "5. PROXY TRANSPARENTE - Site Permitido:"
curl -I http://example.com | head -1
echo ""
echo "6. PROXY TRANSPARENTE - Site Bloqueado (facebook):"
curl -I http://facebook.com 2>&1 | head -1
echo ""
echo "=============================================="
EOF
chmod +x /home/testar-conectividade.sh

cat > /home/testar-proxy.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTE DO PROXY TRANSPARENTE"
echo "=============================================="
echo ""

echo "Sem proxy configurado (transparente):"
echo "http_proxy = $http_proxy"
echo ""

echo "1. Site PERMITIDO (example.com):"
curl -s -I http://example.com | head -1
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
echo "Verifique os logs no firewall:"
echo "sudo tail -f /var/log/squid/access.log"
echo "=============================================="
EOF

chmod +x /home/testar-proxy.sh

cat > /home/testar-tudo.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTE COMPLETO - TRABALHO SEGURANÇA"
echo "=============================================="
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Função de teste
test_cmd() {
    if $1 >/dev/null 2>&1; then
        echo -e "${GREEN}$2${NC}"
    else
        echo -e "${RED}$2${NC}"
    fi
}

echo "1. CONECTIVIDADE BÁSICA:"
test_cmd "ping -c 1 192.168.1.1" "Gateway (firewall)"
test_cmd "ping -c 1 10.0.0.2" "Servidor WEB (DMZ)"
test_cmd "ping -c 1 8.8.8.8" "Internet (IP)"
test_cmd "ping -c 1 google.com" "Internet (DNS)"
echo ""

echo "2. ACESSO AO SERVIDOR WEB:"
test_cmd "curl -s http://10.0.0.2 > /dev/null" "HTTP - Servidor WEB"
curl -s http://10.0.0.2 | grep -o "<h1>.*</h1>"
echo ""

echo "3. PROXY TRANSPARENTE:"
if curl -s -I http://example.com | grep -q "200 OK"; then
    echo -e "${GREEN}Site permitido (example.com) - OK${NC}"
else
    echo -e "${RED}Site permitido (example.com) - FALHOU${NC}"
fi

if curl -s -I http://facebook.com 2>&1 | grep -q "403\|denied"; then
    echo -e "${GREEN}Site bloqueado (facebook.com) - BLOQUEADO${NC}"
else
    echo -e "${RED}Site bloqueado (facebook.com) - NÃO BLOQUEADO${NC}"
fi
echo ""
echo "=============================================="
echo "TESTES CONCLUÍDOS"
echo "=============================================="
EOF
chmod +x /home/testar-tudo.sh
echo ""
echo "=== TESTES INICIAIS ==="
ping -c 1 192.168.1.1 >/dev/null && echo "Gateway OK" || echo "Gateway falhou"
ping -c 1 8.8.8.8 >/dev/null && echo "Internet OK" || echo "Internet falhou"
echo "=============================================="
echo "CLIENTE CONFIGURADO COM SUCESSO!"
echo "IP: 192.168.1.100"
echo "Gateway: 192.168.1.1"
echo ""
echo "SCRIPTS DE TESTE CRIADOS:"
echo "  /home/testar-conectividade.sh"
echo "  /home/testar-proxy.sh"
echo "  /home/testar-tudo.sh"
echo ""
echo "PARA TESTAR:"
echo "  bash /home/testar-tudo.sh"
echo ""
echo "ACESSAR SERVIDOR WEB:"
echo "  curl http://10.0.0.2"
echo "  firefox http://10.0.0.2"
echo "=============================================="