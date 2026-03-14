#!/bin/bash
# configurar-bloqueio-https.sh
# por conta que nao conseguimos bloquear por nome de dominio, vamos bloquear por IP as faixas de IPs dos sites bloqueados na blacklist do squid. Assim, mesmo que o cliente tente acessar por IP, o firewall irá bloquear o acesso.
echo "=== CONFIGURANDO BLOQUEIO HTTPS POR IP ==="

# facebook
sudo iptables -A FORWARD -d 31.13.0.0/16 -j DROP
sudo iptables -A FORWARD -d 69.171.0.0/16 -j DROP
sudo iptables -A FORWARD -d 173.252.0.0/16 -j DROP
sudo iptables -A FORWARD -d 66.220.0.0/16 -j DROP
sudo iptables -A FORWARD -d 179.60.0.0/16 -j DROP
sudo iptables -A FORWARD -d 157.240.0.0/16 -j DROP

# youTube
sudo iptables -A FORWARD -d 172.217.0.0/16 -j DROP
sudo iptables -A FORWARD -d 173.194.0.0/16 -j DROP

# isnta
sudo iptables -A FORWARD -d 52.0.0.0/8 -m string --string "instagram" --algo bm -j DROP
sudo netfilter-persistent save

echo "Bloqueios HTTPS configurados"