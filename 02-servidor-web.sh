#!/bin/bash
set -e

echo "=============================================="
echo "SERVIDOR WEB (DMZ) - Configuração Automática"
echo "=============================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "xecute como root: sudo bash 02-servidor-web.sh"
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

echo "  ✓ Interface $IFACE configurada: 10.0.0.2/24"
echo "[2/4] Configurando DNS..."

systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "DNS configurado"
echo "[3/4] Instalando Apache..."

apt update
apt install -y apache2 php libapache2-mod-php

cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Servidor WEB - Campus Quixadá</title>
    <style>
        body { font-family: Arial; text-align: center; margin-top: 50px; background-color: #f0f0f0; }
        .container { background: white; padding: 30px; border-radius: 10px; width: 80%; margin: auto; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; }
        .info { background: #ecf0f1; padding: 20px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Servidor WEB da Organização</h1>
        <div class="info">
            <h2>Campus Quixadá - Segurança da Informação</h2>
            <p><strong>IP do Servidor:</strong> 10.0.0.2 (DMZ)</p>
            <p><strong>Gateway:</strong> 10.0.0.1 (Firewall)</p>
            <p><strong>Status:</strong> <span class="success">DMZ - Acesso Permitido</span></p>
            <p><strong>Data e Hora:</strong> <?php echo date('d/m/Y H:i:s'); ?></p>
            <p><strong>Trabalho:</strong> TP1 - Segurança da Informação</p>
            <p><strong>Equipe:</strong> Halyson Lima João Victor Braz</p>
        </div>
    </div>
</body>
</html>
EOF

cp /var/www/html/index.html /var/www/html/index.php

a2enmod php
systemctl restart apache2

echo "  ✓ Apache instalado e configurado"

echo "[4/4] Executando testes..."

echo ""
echo "=== TESTES DE CONECTIVIDADE ==="
echo "Gateway (firewall): $(ping -c 1 10.0.0.1 >/dev/null && echo 'OK' || echo 'FALHOU')"
echo "Internet (8.8.8.8): $(ping -c 1 8.8.8.8 >/dev/null && echo 'OK' || echo 'FALHOU')"
echo "DNS (google.com): $(ping -c 1 google.com >/dev/null && echo 'OK' || echo 'FALHOU')"
echo ""
echo "Servidor WEB local:"
curl -s http://10.0.0.2 | grep -o "<h1>.*</h1>" || echo "❌ Falha no servidor web"

echo "=============================================="
echo "SERVIDOR WEB CONFIGURADO COM SUCESSO!"
echo "IP: 10.0.0.2"
echo "Gateway: 10.0.0.1"
echo "Acesse: http://10.0.0.2"
echo ""
echo "PRÓXIMO PASSO: Configurar o Cliente (03-cliente.sh)"
echo "=============================================="