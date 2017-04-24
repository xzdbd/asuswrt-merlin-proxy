#!/bin/sh

if iptables -t nat -N SHADOWSOCKS; then
	iptables -t nat -A SHADOWSOCKS -d SS-SERVER-IP -j RETURN

	iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

	/jffs/scripts/iptables-ch.sh

	iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports SS-LOCAL-PORT

	iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS

	iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
fi

