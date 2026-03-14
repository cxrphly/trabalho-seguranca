# README - Trabalho Prático de Segurança da Informação
## Campus de Quixadá - UFC
### Configuração de Firewall e Proxy com iptables e Squid

---

## 1. Visão Geral

Implementação de infraestrutura de rede com firewall stateful e proxy Squid para controle de acesso. O cenário possui duas redes internas (LAN Cliente e DMZ) protegidas por um firewall/roteador.

### Objetivos
- Filtro de pacotes stateful com iptables (política padrão DROP)
- NAT para acesso à internet (SNAT) e exposição de serviços (DNAT)
- Proxy HTTP/HTTPS com Squid e blacklist de domínios
- Servidor Web interno na DMZ
- Segmentação de rede (LAN Cliente 10.0.3.0/24 e DMZ 10.0.4.0/24)

---

## 2. Topologia de Rede

```
                    INTERNET
                        |
                        | (enp0s3 - DHCP)
                        |
                +---------------+
                |   FIREWALL    |
                |   (10.0.3.1)  |
                |   (10.0.4.1)  |
                +---------------+
                  |           |
        (enp0s8)  |           |  (enp0s9)
        10.0.3.1  |           |  10.0.4.1
                  |           |
        +---------+           +---------+
        |                               |
        |                               |
+---------------+               +---------------+
|  LAN CLIENTE  |               |      DMZ      |
|  10.0.3.0/24  |               |  10.0.4.0/24  |
+---------------+               +---------------+
        |                               |
        |                               |
+---------------+               +---------------+
|    Cliente    |               | Servidor Web  |
|  10.0.3.10    |               |  10.0.4.10    |
+---------------+               +---------------+
```

### Componentes

| Componente | Função | IPs |
|------------|--------|-----|
| Firewall | Roteamento, filtro, NAT, proxy | enp0s3: DHCP, enp0s8: 10.0.3.1, enp0s9: 10.0.4.1 |
| Servidor Web | Site institucional | 10.0.4.10 |
| Cliente | Estação interna | 10.0.3.10 |

### Regras de Firewall

**Firewall:**
- SSH (22), ICMP, DNS (53)

**DMZ (10.0.4.10):**
- HTTP (80), HTTPS (443), ICMP

**Rede Cliente (10.0.3.0/24):**
- SSH (22), DNS (53), HTTP/HTTPS (80,443), FTP (21), SMTP (25), ICMP

**Blacklist Squid:**
- .facebook.com, .youtube.com, .instagram.com, .tiktok.com, .twitter.com, .netflix.com, .spotify.com, .twitch.tv

---

## 3. Configuração das VMs no VirtualBox

### VM Firewall
- Nome: firewall
- SO: Ubuntu Server 20.04/22.04
- RAM: 1024 MB
- Disco: 10 GB
- Adaptador 1: NAT (enp0s3 - WAN)
- Adaptador 2: Rede Interna "lan_cliente" (enp0s8)
- Adaptador 3: Rede Interna "dmz" (enp0s9)

### VM Servidor Web
- Nome: server-web
- SO: Ubuntu Server
- RAM: 1024 MB
- Disco: 10 GB
- Adaptador 1: Rede Interna "dmz" (enp0s3)

### VM Cliente
- Nome: cliente
- SO: Ubuntu 
- RAM: 2048 MB
- Disco: 20 GB
- Adaptador 1: Rede Interna "lan_cliente" (enp0s3)

### Ordem de Inicialização
1. Firewall
2. Servidor Web
3. Cliente

---

## 4. Instruções de Execução

### Preparação Inicial (todas as VMs)
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y net-tools curl wget vim
```

### No Firewall
```bash
sudo bash ./firewall.sh
```

### No Servidor Web
```bash
sudo bash /servidor-web.sh
```

### No Cliente
```bash
sudo bash./cliente.sh

```

---

## 5. Testes Rápidos

### Haverá testes nas VM
```bash
echo "SCRIPTS DISPONÍVEIS:"
echo "  /root/
```

### Verificar logs do Squid (no firewall)
```bash
sudo tail -f /var/log/squid/access.log
```

### Testar sites manualmente
```bash
curl -I http://www.google.com
curl -I http://www.facebook.com
```

---

