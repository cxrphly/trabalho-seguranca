#!/bin/bash

set -e

echo "RESETANDO AMBIENTE..."

apt update
apt install -y squid apache2 iptables iptables-persistent curl

systemctl stop squid || true

echo "LIMPANDO CONFIGS ANTIGAS..."

rm -f /etc/squid/squid.conf
rm -rf /var/spool/squid/*
rm -f /etc/squid/blacklist.txt

echo "COPIANDO NOVAS CONFIGURACOES..."

cp squid.conf /etc/squid/squid.conf
cp blacklist.txt /etc/squid/blacklist.txt

chown proxy:proxy /etc/squid/blacklist.txt

echo "INICIALIZANDO CACHE SQUID..."

squid -z

systemctl enable squid
systemctl restart squid

echo "CONFIGURANDO IP FORWARD..."

echo 1 > /proc/sys/net/ipv4/ip_forward

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

echo "APLICANDO REGRAS IPTABLES..."

bash iptables.sh

netfilter-persistent save

echo "FIREWALL CONFIGURADO"