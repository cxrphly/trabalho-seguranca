#!/bin/bash

echo "=== Configurando Cliente ==="

CLIENTE_IF=$(ip link | grep -E "enp0s3|ens3" | cut -d: -f2 | tr -d ' ' | head -1)
[ -z "$CLIENTE_IF" ] && CLIENTE_IF="enp0s3"

cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $CLIENTE_IF:
      addresses:
        - 10.0.3.10/24
      routes:
        - to: default
          via: 10.0.3.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

netplan apply
sleep 5

apt-get update
apt-get install -y curl wget ftp lynx telnet netcat

cat >> /etc/environment << EOF
http_proxy=http://10.0.3.1:3128
https_proxy=http://10.0.3.1:3128
ftp_proxy=http://10.0.3.1:3128
HTTP_PROXY=http://10.0.3.1:3128
HTTPS_PROXY=http://10.0.3.1:3128
FTP_PROXY=http://10.0.3.1:3128
no_proxy=localhost,127.0.0.1,10.0.0.0/8
NO_PROXY=localhost,127.0.0.1,10.0.0.0/8
EOF

cat > /etc/apt/apt.conf.d/proxy.conf << EOF
Acquire::http::Proxy "http://10.0.3.1:3128";
Acquire::https::Proxy "http://10.0.3.1:3128";
EOF

cat > /home/$USER/testar.sh << 'EOF'
#!/bin/bash
echo "=== TESTES ==="
echo "1. Ping firewall:"
ping -c 2 10.0.3.1 2>&1 | head -3
echo ""
echo "2. Ping servidor web:"
ping -c 2 10.0.4.10 2>&1 | head -3
echo ""
echo "3. Ping internet:"
ping -c 2 8.8.8.8 2>&1 | head -3
echo ""
echo "4. DNS:"
nslookup google.com 2>&1 | grep Address | head -3
echo ""
echo "5. Acesso servidor web HTTP:"
curl -s -I http://10.0.4.10 2>/dev/null | head -1
echo ""
echo "6. Acesso servidor web HTTPS:"
curl -s -k -I https://10.0.4.10 2>/dev/null | head -1
echo ""
echo "7. Acesso internet:"
curl -s -I http://www.google.com 2>/dev/null | head -1
echo ""
echo "8. Teste blacklist (facebook):"
curl -s -I http://www.facebook.com 2>&1 | head -2
echo ""
echo "9. Proxy configurado:"
env | grep -i proxy
EOF

chmod +x /home/$USER/testar.sh

echo "Cliente configurado. IP: 10.0.3.10, Gateway: 10.0.3.1, Proxy: 10.0.3.1:3128"
echo "Faça logout/login para ativar o proxy. Execute ./testar.sh para testar."