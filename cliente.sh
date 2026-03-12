#!/bin/bash

echo "Configurando cliente..."

apt update
apt install -y curl wget dnsutils

IF=enp0s3

cat > /etc/netplan/01-client.yaml <<EOF
network:
 version: 2
 renderer: networkd
 ethernets:
  $IF:
   addresses:
    - 10.0.3.10/24
   routes:
    - to: default
      via: 10.0.3.1
   nameservers:
    addresses: [8.8.8.8]
EOF

netplan apply

echo "Configurando proxy..."

cat >> /etc/environment <<EOF
http_proxy=http://10.0.3.1:3128
https_proxy=http://10.0.3.1:3128
EOF

cat > ~/teste.sh <<EOF
#!/bin/bash

echo "PING FIREWALL"
ping -c 2 10.0.3.1

echo "PING SERVIDOR"
ping -c 2 10.0.4.10

echo "TESTE WEB"
curl http://10.0.4.10

echo "TESTE GOOGLE"
curl http://google.com

echo "TESTE BLOQUEIO"
curl http://facebook.com
EOF

chmod +x ~/teste.sh

echo "Cliente configurado"