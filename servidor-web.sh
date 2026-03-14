#!/bin/bash
# servidor-web.sh - Configuração do Servidor WEB na DMZ
# Execute: sudo bash servidor-web.sh

set -e

echo "=============================================="
echo "SERVIDOR WEB (DMZ) - CONFIGURAÇÃO COMPLETA"
echo "=============================================="

if [ "$EUID" -ne 0 ]; then
    echo "Execute como root: sudo bash servidor-web.sh"
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
        - 10.0.0.2/24
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      dhcp4: false
EOF

netplan apply
sleep 3

echo "  Interface $IFACE configurada: 10.0.0.2/24"
echo "[2/4] Configurando DNS..."

systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true

rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "  DNS configurado"

echo "[3/4] Instalando Apache..."

apt update
apt install -y apache2 php libapache2-mod-php

cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Servidor WEB - Campus Quixada</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; width: 80%; margin: auto; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { color: #0066cc; }
        .info { background: #e8f4f8; padding: 20px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .ip { font-family: monospace; background: #eee; padding: 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Servidor WEB da Organizacao</h1>
        <div class="info">
            <h2>Campus Quixada - Seguranca da Informacao</h2>
            <p><strong>Status:</strong> <span class="success">DMZ - Acesso Permitido</span></p>
            <p><strong>IP do Servidor:</strong> <span class="ip">10.0.0.2</span></p>
            <p><strong>Gateway:</strong> <span class="ip">10.0.0.1</span> (Firewall)</p>
            <p><strong>Data e Hora:</strong> <?php echo date('d/m/Y H:i:s'); ?></p>
            <p><strong>Trabalho:</strong> TP1 - Seguranca da Informacao</p>
            <p><strong>Grupo:</strong> Equipe</p>
        </div>
    </div>
</body>
</html>
EOF

cp /var/www/html/index.html /var/www/html/index.php

a2enmod php
systemctl restart apache2

echo "  Apache instalado e configurado"

echo "[4/4] Criando scripts de teste..."

cat > /root/testar-servidor.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "TESTES DO SERVIDOR WEB"
echo "=============================================="
echo ""
echo "1. GATEWAY (firewall):"
ping -c 2 10.0.0.1
echo ""
echo "2. INTERNET (8.8.8.8):"
ping -c 2 8.8.8.8
echo ""
echo "3. DNS (google.com):"
ping -c 2 google.com
echo ""
echo "4. SERVIDOR WEB LOCAL:"
curl -s http://10.0.0.2 | grep -o "<h1>.*</h1>"
echo ""
echo "=============================================="
EOF

chmod +x /root/testar-servidor.sh


echo "=============================================="
echo "SERVIDOR WEB CONFIGURADO"
echo "=============================================="
echo ""
echo "ACESSOS:"
echo "  IP: 10.0.0.2"
echo "  Gateway: 10.0.0.1"
echo "  Página: http://10.0.0.2"
echo ""
echo "TESTES:"
echo "  /root/testar-servidor.sh"
echo ""
echo "=============================================="