#!/bin/bash

echo "Configurando servidor WEB..."

apt update
apt install -y apache2 curl

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
    addresses: [8.8.8.8]
EOF

netplan apply

cat > /var/www/html/index.html <<EOF
<html>
<h1>Servidor Web da Organizacao</h1>
<p>DMZ funcionando</p>
</html>
EOF

systemctl restart apache2
systemctl enable apache2

echo "Servidor WEB configurado"