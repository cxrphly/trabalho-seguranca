#!/bin/bash

echo "=== Configurando Servidor Web ==="

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

echo "Testando conectividade com firewall..."
if ! ping -c 2 10.0.4.1 > /dev/null 2>&1; then
    echo "ERRO: Sem comunicação com firewall"
    exit 1
fi

echo "Testando acesso a internet..."
if ping -c 2 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet OK. Instalando pacotes..."
    apt-get update
    apt-get install -y apache2
else
    echo "Sem internet. Continuando com instalação offline..."
    
    mkdir -p /tmp/pacotes
    cd /tmp/pacotes
    
    if [ ! -f /tmp/pacotes/apache2.deb ]; then
        echo "Baixe os pacotes manualmente:"
        echo "Em outra maquina com internet:"
        echo "  apt-get download apache2 apache2-utils openssl ssl-cert"
        echo "Copie para este diretorio e execute:"
        echo "  dpkg -i *.deb"
        echo "  apt-get install -f -y"
    else
        dpkg -i *.deb 2>/dev/null
        apt-get install -f -y
    fi
fi

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
</body>
</html>
EOF

mkdir -p /etc/apache2/ssl
mkdir -p /etc/ssl

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/server.key \
    -out /etc/ssl/server.crt \
    -subj "/C=BR/ST=CE/L=Quixada/O=UFC/CN=quixada.local" 2>/dev/null

if command -v apache2 > /dev/null 2>&1; then
    cp /etc/ssl/server.key /etc/apache2/ssl/
    cp /etc/ssl/server.crt /etc/apache2/ssl/
    
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
    echo "Apache configurado com sucesso"
else
    echo "Apache nao instalado"
fi

apt-get install -y ufw 2>/dev/null
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable 2>/dev/null

echo "Servidor Web: http://10.0.4.10 e https://10.0.4.10"