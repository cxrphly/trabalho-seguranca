#!/bin/bash

echo "=== Instalando pacotes para analise de sistema ==="

sudo apt update

sudo apt install -y \
    nmap net-tools tcpdump wireshark iftop iptraf-ng \
    curl wget ftp telnet netcat openssl dnsutils \
    lnav multitail auditd logwatch \
    lynis rkhunter chkrootkit fail2ban clamav \
    fastfetch htop

echo "=== Instalação concluída ==="
echo ""
echo "Sugestões para o relatório:"
echo "---------------------------"
echo "1. Execute 'sudo nmap -sS 10.0.3.1' para testar portas abertas"
echo "2. Execute 'sudo tail -f /var/log/squid/access.log' para monitorar o proxy"
echo "3. Execute 'sudo lynis audit system' para gerar relatório de segurança"
echo "4. Execute 'fastfetch' para capturar informações do sistema"
