#!/bin/bash

echo "=== CONFIGURACAO DO SERVIDOR WEB ==="

WEB_IF=$(ip link | grep -E "enp0s3|ens3" | cut -d: -f2 | tr -d ' ' | head -1)
[ -z "$WEB_IF" ] && WEB_IF="enp0s3"

cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $WEB_IF:
      addresses:
        - 10.0.4.10/24
      routes:
        - to: default
          via: 10.0.4.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply
sleep 5

echo "Testando conectividade..."
ping -c 2 10.0.4.1 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERRO: Sem comunicacao com firewall"
    exit 1
fi

echo "Instalando Apache..."
apt-get update
apt-get install -y apache2

cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Campus de Quixada - UFC</title>
</head>
<body>
    <h1>Campus de Quixada - UFC</h1>
    <p>Trabalho Pratico de Seguranca da Informacao</p>
    <p>Servidor Web: 10.0.4.10</p>
    <p>Firewall: 10.0.4.1</p>
    <p>Status: Funcionando</p>
</body>
</html>
EOF

mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/server.key \
    -out /etc/apache2/ssl/server.crt \
    -subj "/C=BR/ST=CE/L=Quixada/O=UFC/CN=quixada.local"

a2enmod ssl
cat > /etc/apache2/sites-available/default-ssl.conf << 'EOF'
<VirtualHost *:443>
    ServerAdmin webmaster@quixada.local
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/server.crt
    SSLCertificateKeyFile /etc/apache2/ssl/server.key
</VirtualHost>
EOF

a2ensite default-ssl.conf
systemctl restart apache2

echo "Servidor Web configurado: http://10.0.4.10 e https://10.0.4.10"