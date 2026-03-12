#!/bin/bash

echo "Configurando servidor WEB..."

apt update
apt install -y apache2 curl net-tools

IF=enp0s3

cat > /etc/netplan/01-server.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IF:
      addresses:
        - 10.0.4.10/24
      routes:
        - to: default
          via: 10.0.4.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF

netplan apply
sleep 3

echo "Configurando pagina web..."

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Servidor Web DMZ</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 50px;
            background-color: #f0f0f0;
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        .info {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="info">
        <h1>Servidor Web da Organizacao</h1>
        <p>DMZ funcionando corretamente</p>
        <p><strong>IP:</strong> 10.0.4.10</p>
        <p><strong>Data:</strong> $(date)</p>
    </div>
</body>
</html>
EOF

echo "Configurando virtual host..."

cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo "Habilitando modulos..."

a2enmod rewrite
systemctl restart apache2
systemctl enable apache2

echo "Configurando testes..."

cat > ~/teste.sh <<EOF
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n\033[1mTESTES DO SERVIDOR WEB\033[0m\n"

echo -n "PING GATEWAY (10.0.4.1): "
if ping -c 2 -W 2 10.0.4.1 > /dev/null 2>&1; then
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

echo -e "\n\033[1mTESTE SERVIDOR LOCAL\033[0m\n"
echo "Pagina web:"
curl -s http://localhost | grep -o "<h1>.*</h1>" | sed 's/<[^>]*>//g'

echo -e "\nPorta 80:"
if netstat -tlnp | grep :80 > /dev/null; then
    echo -e "${GREEN}Apache rodando na porta 80${NC}"
else
    echo -e "${RED}Apache nao esta rodando${NC}"
fi

echo -e "\n\033[1mINFORMACOES DO SERVIDOR\033[0m\n"
echo "IP: \$(ip -4 addr show $IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
echo "Gateway: \$(ip route | grep default | awk '{print \$3}')"
echo "Hostname: \$(hostname)"
echo "Apache: \$(apache2 -v | head -n1)"
EOF

chmod +x ~/teste.sh

cat >> ~/.bashrc <<EOF
alias testar='~/teste.sh'
alias ip='ip -c addr'
alias logs='tail -f /var/log/apache2/access.log'
EOF

echo ""
echo "===================================="
echo "Servidor WEB configurado com sucesso!"
echo "===================================="
echo ""
echo "IP: 10.0.4.10/24"
echo "Gateway: 10.0.4.1"
echo ""
echo "Comandos uteis:"
echo "  testar     - Executar testes do servidor"
echo "  logs       - Ver logs do Apache"
echo "  ip         - Ver configuração de IP"
echo ""
echo "Acesse: http://10.0.4.10"
echo "===================================="