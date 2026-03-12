#!/bin/bash

apt update
apt install -y apache2

cat <<EOF > /var/www/html/index.html
<h1>Site da Organização</h1>
<p>Servidor Web da DMZ funcionando.</p>
EOF

systemctl enable apache2
systemctl restart apache2

echo "Servidor WEB configurado"