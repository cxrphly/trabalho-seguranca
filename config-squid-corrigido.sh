#!/bin/bash
# config-squid-corrigido.sh

echo "=== CONFIGURANDO SQUID CORRETAMENTE ==="

# Parar squid
sudo systemctl stop squid

# Limpar cache
sudo rm -rf /var/spool/squid/*
sudo rm -rf /var/log/squid/*
sudo mkdir -p /var/spool/squid
sudo mkdir -p /var/log/squid
sudo chown -R proxy:proxy /var/spool/squid
sudo chown -R proxy:proxy /var/log/squid

# Dar permissão especial
sudo setcap 'cap_net_bind_service=ep' /usr/sbin/squid 2>/dev/null || true

# Configuração
sudo tee /etc/squid/squid.conf > /dev/null <<'EOF'
# PROXY TRANSPARENTE - CONFIGURAÇÃO CORRIGIDA
http_port 3128 intercept

# ACLs
acl rede_interna src 192.168.1.0/24
acl dmz src 10.0.0.0/24
acl localhost src 127.0.0.1/32
acl all src 0.0.0.0/0

# Portas seguras
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

# Blacklist
acl blacklist dstdomain "/etc/squid/blacklist.txt"

# REGRAS (ORDEM CORRETA)
http_access deny blacklist
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow rede_interna
http_access allow dmz
http_access deny all

# Cache
cache_mem 8 MB
cache_dir ufs /var/spool/squid 100 16 256
maximum_object_size 4 MB

# Logs
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Importante para intercept
via off
forwarded_for off

# Nome do host
visible_hostname firewall-tp1
EOF

# Criar blacklist
sudo tee /etc/squid/blacklist.txt > /dev/null <<EOF
.facebook.com
.youtube.com
.instagram.com
EOF

# Testar configuração
echo "Testando configuração..."
sudo squid -k parse

if [ $? -eq 0 ]; then
    echo "Configuração OK!"
    sudo squid -z
    sudo systemctl start squid
    sleep 2
    sudo systemctl status squid --no-pager
else
    echo "ERRO na configuração!"
    exit 1
fi

echo "=== CONFIGURAÇÃO CONCLUÍDA ==="