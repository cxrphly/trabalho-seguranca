#!/bin/bash

set -e

echo "================================="
echo "CONFIGURANDO SERVIDOR WEB (DMZ)"
echo "================================="

sleep 2

echo "Atualizando pacotes..."
apt update

echo "Instalando Apache..."
apt install -y apache2 curl net-tools

IF=enp0s3

echo "Configurando rede..."

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

echo "Rede configurada."

echo "Configurando pagina web..."

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Servidor Web DMZ</title>
<style>
body {
font-family: Arial;
margin: 50px;
background:#f0f0f0;
}
.box{
background:white;
padding:20px;
border-radius:6px;
box-shadow:0 0 10px rgba(0,0,0,0.1);
}
</style>
</head>

<body>

<div class="box">

<h1>Servidor Web da Organizacao</h1>

<p>Servidor localizado na DMZ</p>

<p><b>IP:</b> 10.0.4.10</p>

<p><b>Data:</b> $(date)</p>

</div>

</body>
</html>
EOF

echo "Configurando VirtualHost..."

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

echo "Reiniciando Apache..."

systemctl restart apache2
systemctl enable apache2

sleep 2

echo "Criando script de testes..."

cat > ~/teste.sh <<EOF
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\nTESTES DO SERVIDOR WEB\n"

echo -n "PING GATEWAY (10.0.4.1): "
if ping -c 2 -W 2 10.0.4.1 > /dev/null; then
echo -e "\${GREEN}OK\${NC}"
else
echo -e "\${RED}FALHOU\${NC}"
fi

echo -n "PING INTERNET (8.8.8.8): "
if ping -c 2 -W 2 8.8.8.8 > /dev/null; then
echo -e "\${GREEN}OK\${NC}"
else
echo -e "\${RED}FALHOU\${NC}"
fi

echo -e "\nTESTE SERVIDOR LOCAL\n"

curl -s http://localhost | grep Servidor

echo -e "\nPORTA 80"

if ss -tln | grep :80 > /dev/null; then
echo -e "\${GREEN}Apache rodando na porta 80\${NC}"
else
echo -e "\${RED}Apache nao esta rodando\${NC}"
fi

echo -e "\nINFORMACOES"

echo "IP: \$(hostname -I)"
echo "Gateway: \$(ip route | grep default | awk '{print \$3}')"
echo "Hostname: \$(hostname)"

EOF

chmod +x ~/teste.sh

cat >> ~/.bashrc <<EOF
alias testar='~/teste.sh'
alias logs='tail -f /var/log/apache2/access.log'
alias ip='ip -c addr'
EOF

echo ""
echo "================================="
echo "SERVIDOR WEB CONFIGURADO"
echo "================================="
echo ""
echo "IP: 10.0.4.10"
echo "Gateway: 10.0.4.1"
echo ""
echo "Execute:"
echo "testar"
echo ""
echo "Acesse:"
echo "http://10.0.4.10"
echo "================================="