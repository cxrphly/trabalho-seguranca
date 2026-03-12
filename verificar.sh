#!/bin/bash

echo "=== VERIFICACAO DO AMBIENTE ==="
echo

echo "1. Interfaces de rede:"
ip -4 addr show | grep -E "enp|ens|inet" | grep -v "127.0.0.1"
echo

echo "2. Rotas:"
ip route show
echo

echo "3. Servicos:"
for service in ssh apache2 squid; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "$service: ATIVO"
    else
        echo "$service: INATIVO"
    fi
done
echo

echo "4. Iptables (resumo):"
sudo iptables -L 2>/dev/null | grep -E "Chain|ACCEPT" | head -10
echo

echo "5. Internet:"
ping -c 1 8.8.8.8 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Internet: OK"
else
    echo "Internet: FALHA"
fi
echo

echo "6. Proxy:"
if [ -n "$http_proxy" ]; then
    echo "Proxy: $http_proxy"
else
    echo "Proxy: NAO CONFIGURADO"
fi