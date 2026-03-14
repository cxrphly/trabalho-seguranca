## README - Trabalho Prático de Segurança da Informação
### Campus de Quixadá - UFC

---

## 1. Sobre o Projeto

Implementação de infraestrutura de rede com firewall stateful (iptables) e proxy Squid para controle de acesso. O cenário possui duas redes internas (LAN Cliente e DMZ) protegidas por um firewall/roteador.

---

## 2. Topologia de Rede

```
                    INTERNET
                        |
                        | (enp0s3 - DHCP)
                        |
                +-----------------+
                |   FIREWALL      |
                |   (192.168.1.1) |
                |   (10.0.0.1)    |
                +-----------------+
                  |           |
        (enp0s8)  |           |  (enp0s9)
        192.168.1.1|           |  10.0.0.1
                  |           |
        +---------+           +---------+
        |                               |
        |                               |
+---------------+               +---------------+
|  LAN CLIENTE  |               |      DMZ      |
| 192.168.1.0/24|               |  10.0.0.0/24  |
+---------------+               +---------------+
        |                               |
        |                               |
+---------------+               +---------------+
|    Cliente    |               | Servidor Web  |
|  192.168.1.100|               |   10.0.0.2    |
+---------------+               +---------------+
```

---

## 3. Configuração das VMs no VirtualBox

| VM | RAM | Disco | Adaptador 1 | Adaptador 2 | Adaptador 3 |
|-----|-----|-------|-------------|-------------|-------------|
| **Firewall** | 1GB | 20GB | NAT (enp0s3) | Rede Interna "lan" (enp0s8) | Rede Interna "dmz" (enp0s9) |
| **Servidor Web** | 1GB | 10GB | Rede Interna "dmz" (enp0s3) | - | - |
| **Cliente** | 2GB | 20GB | Rede Interna "lan" (enp0s3) | - | - |

**Ordem de inicialização:** Firewall -> Servidor Web -> Cliente

---

## 4. Como Usar

### Clone o repositório em cada máquina:

```bash
git clone https://github.com/cxrphly/trabalho-seguranca.git
cd trabalho-seguranca
```

### Execute o script correspondente em cada VM:

| Máquina | Comando |
|---------|---------|
| **Firewall** | `sudo bash /firewall.sh` |
| **Servidor Web** | `sudo bash /servidor-web.sh` |
| **Cliente** | `sudo bash /cliente.sh` |

### No cliente, configure o proxy:

```bash
source ~/.bashrc
# ou
export http_proxy=http://192.168.1.1:3128
export https_proxy=http://192.168.1.1:3128
```

---

## 5. Testes Rápidos

No cliente, execute:

```bash
# Teste completo
bash /home/aluno/testar-tudo.sh

# Testes manuais
curl -I http://example.com
curl -I http://facebook.com
curl http://10.0.0.2
```

No firewall, monitore os logs:

```bash
sudo tail -f /var/log/squid/access.log
```

---

## 6. Requisitos Atendidos

- [x] Política padrão DROP no iptables
- [x] SSH, ICMP e DNS liberados para o firewall
- [x] DMZ com HTTP, HTTPS e ICMP para o servidor web
- [x] LAN com SSH, DNS, HTTP, HTTPS, FTP, SMTP e ICMP
- [x] SNAT (LAN → Internet)
- [x] DNAT (Internet → Servidor Web)
- [x] Proxy Squid com blacklist

---

## 8. Possíveis Problemas

| Problema | Solução |
|----------|---------|
| Cliente sem internet | Verificar SNAT: `sudo iptables -t nat -L` |
| Squid não inicia | Usar configuração mínima: `http_port 3128` e `http_access allow all` |
| HTTPS não bloqueia | Bloquear por IP no firewall (já incluso no script) |

---


**Links Úteis:**
- [VirtualBox](https://www.virtualbox.org/)
- [Ubuntu 24.04 LTS](https://releases.ubuntu.com/24.04/)