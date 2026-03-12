#!/bin/bash

echo "=== INSTALANDO PACOTES ADICIONAIS ==="

apt-get update

PACOTES="nmap net-tools tcpdump wireshark iftop iptraf-ng curl wget ftp telnet netcat openssl dnsutils lnav multitail auditd logwatch lynis rkhunter chkrootkit fail2ban clamav asciinema fastfetch htop"

for pacote in $PACOTES; do
    echo "Instalando $pacote..."
    apt-get install -y $pacote 2>/dev/null
done

echo "Pacotes instalados."
echo
echo "Comandos uteis para o relatorio:"
echo "  nmap -sS 10.0.3.1"
echo "  sudo tail -f /var/log/squid/access.log"
echo "  sudo lynis audit system"
echo "  fastfetch"
