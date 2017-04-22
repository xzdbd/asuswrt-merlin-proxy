# Manual

1. Set up U disk to ext3

2. Set up entware

3. opkg install shadowsocks-libev vim bash

4. setup /opt/etc/shadowsocks.json

5. Change /opt/etc/init.d/S22shadowsocks

	```bash
	#!/bin/sh

	ENABLED=yes
	PROCS=ss-redir
	ARGS="-c /opt/etc/shadowsocks.json"
	PREARGS=""
	DESC=$PROCS
	PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

	. /opt/etc/init.d/rc.func
	```
6. Start shadowsocks: /opt/etc/init.d/S22shadowsocks start

7. Set up iptables.
	
	```bash
	iptables -t nat -N SHADOWSOCKS

	iptables -t nat -A SHADOWSOCKS -d <SS-SERVER-IP> -j RETURN

	iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

	<iptables-ch.sh>

	iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports <SS-LOCAL-PORT>

	iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS

	iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
	```

	where <iptables-ch.sh> is the bestroutetb list.

8. Set up Dynamic DNS

	```bash
	cd /jffs/configs
	wget https://haoel.github.io/downloads/dnsmasq.conf.add
	service restart_dnsmasq
	```	

	Then reconnect to router.

