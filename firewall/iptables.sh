#!/bin/bash

WAN=enp0s3
LAN=enp0s8
DMZ=enp0s9

LAN_NET=192.168.1.0/24
DMZ_NET=10.0.0.0/24
WEB_SERVER=10.0.0.10

iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# loopback
iptables -A INPUT -i lo -j ACCEPT

# conexões existentes
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH e ICMP firewall
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT

# DNS firewall
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# DMZ acesso externo
iptables -A FORWARD -p tcp -d $WEB_SERVER --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -d $WEB_SERVER --dport 443 -j ACCEPT
iptables -A FORWARD -p icmp -d $WEB_SERVER -j ACCEPT

# rede cliente
iptables -A FORWARD -s $LAN_NET -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p tcp --dport 21 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p tcp --dport 25 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -s $LAN_NET -p icmp -j ACCEPT

# NAT internet
iptables -t nat -A POSTROUTING -s $LAN_NET -o $WAN -j MASQUERADE

# DNAT internet -> web server
iptables -t nat -A PREROUTING -i $WAN -p tcp --dport 80 -j DNAT --to $WEB_SERVER

# proxy transparente
iptables -t nat -A PREROUTING -s $LAN_NET -p tcp --dport 80 -j REDIRECT --to-port 3128