#!/bin/bash

# Configurações de cores para os logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para log com timestamp
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

info() {
    echo -e "${CYAN}[i] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[!] $1${NC}"
}

error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Função para mostrar regras iptables
show_rules() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    info "REGRAS IPTABLES ATUAIS:"
    echo -e "${PURPLE}───────────────────────────────────────────────────────────────${NC}"
    
    echo -e "${YELLOW}FILTER TABLE (INPUT, FORWARD, OUTPUT):${NC}"
    iptables -L -v -n --line-numbers | head -20
    
    echo -e "\n${YELLOW}NAT TABLE:${NC}"
    iptables -t nat -L -v -n --line-numbers
    
    echo -e "\n${YELLOW}ESTATÍSTICAS DE CONEXÃO:${NC}"
    conntrack -L 2>/dev/null | head -10 || echo "Nenhuma conexão ativa"
    
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Função para mostrar interfaces
show_interfaces() {
    echo -e "\n${CYAN}INTERFACES DE REDE:${NC}"
    ip -br addr show | grep -v lo
    echo ""
}

# Configuração para parar em caso de erro
set -e

# Limpa a tela
clear

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║          CONFIGURAÇÃO DO FIREWALL - INICIANDO               ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

sleep 1

log "${YELLOW}Iniciando configuração do firewall...${NC}"
log "Verificando sistema..."

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
    error "Este script deve ser executado como root!"
    exit 1
fi
success "Permissão root verificada"

echo ""
log "${YELLOW}Fase 1/7: Atualizando sistema e instalando pacotes${NC}"
echo "────────────────────────────────────────────────────────"

info "Atualizando lista de pacotes..."
apt update -y > /tmp/apt-update.log 2>&1
success "Lista de pacotes atualizada"

info "Instalando iptables, squid, iptables-persistent, net-tools, curl..."
apt install -y iptables squid iptables-persistent net-tools curl > /tmp/apt-install.log 2>&1
success "Pacotes instalados com sucesso"

echo ""
log "${YELLOW}Fase 2/7: Ativando roteamento IP${NC}"
echo "────────────────────────────────────────────────────────"

info "Ativando IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p > /tmp/sysctl.log 2>&1
success "IP forwarding ativado permanentemente"

echo ""
log "${YELLOW}Fase 3/7: Verificando interfaces de rede${NC}"
echo "────────────────────────────────────────────────────────"

# Mostra interfaces disponíveis
show_interfaces

# Define interfaces (ajuste conforme necessário)
WAN=enp0s3
LAN=enp0s8
DMZ=enp0s9

info "Interfaces configuradas:"
echo -e "  ${GREEN}WAN:${NC} $WAN (Internet)"
echo -e "  ${GREEN}LAN:${NC} $LAN (Rede interna - 10.0.3.0/24)"
echo -e "  ${GREEN}DMZ:${NC} $DMZ (Zona desmilitarizada - 10.0.4.0/24)"

# Verifica se as interfaces existem
for interface in $WAN $LAN $DMZ; do
    if ip link show $interface > /dev/null 2>&1; then
        success "Interface $interface encontrada"
    else
        warn "Interface $interface não encontrada! Continuando mesmo assim..."
    fi
done

sleep 2

echo ""
log "${YELLOW}Fase 4/7: Configurando rede (netplan)${NC}"
echo "────────────────────────────────────────────────────────"

info "Criando arquivo de configuração netplan..."

cat > /etc/netplan/01-firewall.yaml <<EOF
network:
 version: 2
 renderer: networkd
 ethernets:
  $WAN:
   dhcp4: true
  $LAN:
   addresses:
    - 10.0.3.1/24
  $DMZ:
   addresses:
    - 10.0.4.1/24
EOF

info "Aplicando configurações de rede..."
netplan apply > /tmp/netplan.log 2>&1
success "Rede configurada"

# Mostra as configurações aplicadas
ip -br addr show $WAN $LAN $DMZ 2>/dev/null || warn "Algumas interfaces não estão prontas"

sleep 2

echo ""
log "${YELLOW}Fase 5/7: Configurando regras do firewall${NC}"
echo "────────────────────────────────────────────────────────"

info "Limpando regras antigas..."
iptables -F
iptables -t nat -F
iptables -X
success "Regras antigas removidas"

info "Definindo políticas padrão DROP (bloquear tudo)..."
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
success "Políticas padrão configuradas"

echo ""
info "Configurando regras básicas:"

echo -n "  • Liberando loopback... "
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
success "OK"

echo -n "  • Permitindo conexões estabelecidas... "
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
success "OK"

echo ""
info "Regras para o próprio firewall:"

echo -n "  • Permitindo SSH (porta 22)... "
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
success "OK"

echo -n "  • Permitindo ICMP (ping)... "
iptables -A INPUT -p icmp -j ACCEPT
success "OK"

echo -n "  • Permitindo DNS para updates... "
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
success "OK"

echo -n "  • Permitindo HTTP/HTTPS para updates... "
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
success "OK"

echo ""
info "Regras para rede cliente (LAN - 10.0.3.0/24):"

echo -n "  • Permitindo SSH... "
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 22 -j ACCEPT
success "OK"

echo -n "  • Permitindo DNS... "
iptables -A FORWARD -s 10.0.3.0/24 -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 53 -j ACCEPT
success "OK"

echo -n "  • Permitindo FTP... "
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 21 -j ACCEPT
success "OK"

echo -n "  • Permitindo SMTP... "
iptables -A FORWARD -s 10.0.3.0/24 -p tcp --dport 25 -j ACCEPT
success "OK"

echo -n "  • Permitindo ICMP... "
iptables -A FORWARD -s 10.0.3.0/24 -p icmp -j ACCEPT
success "OK"

echo ""
info "Regras para DMZ (10.0.4.0/24):"

echo -n "  • Permitindo acesso ao servidor web (10.0.4.10:80/443)... "
iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -d 10.0.4.10 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -d 10.0.4.10 -p icmp -j ACCEPT
success "OK"

echo -n "  • Servidor DMZ pode acessar internet (HTTP/HTTPS/DNS)... "
iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s 10.0.4.10 -p udp --dport 53 -j ACCEPT
success "OK"

echo ""
info "Configurando NAT (Network Address Translation):"

echo -n "  • MASQUERADE para LAN... "
iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o $WAN -j MASQUERADE
success "OK"

echo -n "  • MASQUERADE para DMZ... "
iptables -t nat -A POSTROUTING -s 10.0.4.0/24 -o $WAN -j MASQUERADE
success "OK"

echo ""
info "Configurando DNAT (redirecionamento de portas):"

echo -n "  • Redirecionando porta 80 para servidor DMZ (10.0.4.10)... "
iptables -t nat -A PREROUTING -i $WAN -p tcp --dport 80 -j DNAT --to 10.0.4.10
success "OK"

echo -n "  • Redirecionando porta 443 para servidor DMZ (10.0.4.10)... "
iptables -t nat -A PREROUTING -i $WAN -p tcp --dport 443 -j DNAT --to 10.0.4.10
success "OK"

echo ""
log "${YELLOW}Fase 6/7: Configurando Squid Proxy${NC}"
echo "────────────────────────────────────────────────────────"

info "Criando lista de sites bloqueados..."
cat > /etc/squid/blacklist.txt <<EOF
.facebook.com
.youtube.com
.netflix.com
.instagram.com
.tiktok.com
EOF
success "Blacklist criada com 5 sites bloqueados"

info "Configurando squid.conf..."
cat > /etc/squid/squid.conf <<EOF
http_port 3128

acl rede_cliente src 10.0.3.0/24
acl bloqueados dstdomain "/etc/squid/blacklist.txt"

http_access deny bloqueados
http_access allow rede_cliente
http_access deny all

cache_mem 256 MB

access_log /var/log/squid/access.log

visible_hostname firewall

dns_nameservers 8.8.8.8 8.8.4.4
EOF
success "Squid configurado"

info "Reiniciando Squid..."
systemctl restart squid
systemctl enable squid > /dev/null 2>&1
success "Squid reiniciado e habilitado"

echo ""
log "${YELLOW}Fase 7/7: Salvando configurações e finalizando${NC}"
echo "────────────────────────────────────────────────────────"

info "Salvando regras do firewall..."
netfilter-persistent save > /tmp/save-rules.log 2>&1
success "Regras salvas permanentemente"

echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ FIREWALL CONFIGURADO COM SUCESSO!${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Resumo da configuração:${NC}"
echo -e "  ${GREEN}• LAN:${NC} 10.0.3.1/24 (Interface: $LAN)"
echo -e "  ${GREEN}• DMZ:${NC} 10.0.4.1/24 (Interface: $DMZ)"
echo -e "  ${GREEN}• Proxy:${NC} 10.0.3.1:3128"
echo -e "  ${GREEN}• Sites bloqueados:${NC} 5 (redes sociais)"
echo -e "  ${GREEN}• Portas redirecionadas:${NC} 80, 443 → 10.0.4.10"
echo ""

# Mostra estatísticas finais
info "Estatísticas do firewall:"
echo -e "  ${YELLOW}Regras INPUT:${NC} $(iptables -L INPUT | grep -c "ACCEPT") regras ACCEPT"
echo -e "  ${YELLOW}Regras FORWARD:${NC} $(iptables -L FORWARD | grep -c "ACCEPT") regras ACCEPT"
echo -e "  ${YELLOW}Regras NAT:${NC} $(iptables -t nat -L | grep -c "DNAT\|MASQUERADE") regras"

echo ""
info "Para ver todas as regras, execute:"
echo -e "  ${CYAN}iptables -L -v -n --line-numbers${NC}"
echo -e "  ${CYAN}iptables -t nat -L -v -n --line-numbers${NC}"

echo ""
echo -e "${GREEN}✅ Configuração concluída!${NC}"
echo ""