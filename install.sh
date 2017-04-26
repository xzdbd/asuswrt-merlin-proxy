#!/bin/sh

source ./script/functions.sh

# entware-setup.sh; opkg update && opkg upgrade

# Configure shadowsocks
set -e
opkg install shadowsocks-libev
set +e
if [ ! -e ./config/shadowsocks/shadowsocks.json ];then
	cp ./config/shadowsocks/shadowsocks.json /opt/etc/shadowsocks.json
fi

replace_string ss-local ss-redir /opt/etc/init.d/S22shadowsocks

# Configure kcptun
wget -O ./kcptun-linux-arm https://github.com/xtaci/kcptun/releases/download/v20170329/kcptun-linux-arm-20170329.tar.gz
tar xvzf ./kcptun-linux-arm
cp ./client_linux_arm5 /opt/bin/
cp ./config/kcptun/S22kcptun /opt/etc/init.d/S22kcptun
chmod a+rx /opt/etc/init.d/S22kcptun


# Configure dnsmasq
wget -O ./config/dnsmasq/dnsmasq.conf.add https://haoel.github.io/downloads/dnsmasq.conf.add

if [ ! -e ./config/dnsmasq/dnsmasq.conf.add ];then
	cp ./config/dnsmasq/dnsmasq.conf.add /jffs/configs/dnsmasq.conf.add
	dnsmasq --test && kill $(cat /var/run/dnsmasq.pid) && dnsmasq --log-async
	add_service services-start 'dnsmasq --test && kill $(cat /var/run/dnsmasq.pid) && dnsmasq --log-async'
fi

# Configure iptables
ss_server_ip=$(cat /opt/etc/shadowsocks.json |grep 'server"' |cut -d':' -f2|cut -d'"' -f2)
ss_local_port=$(cat /opt/etc/shadowsocks.json |grep 'local_port"' |grep -o '[0-9]*')

replace_string 'SS_SERVER_IP' $ss_server_ip /script/iptables.sh
replace_string 'SS_LOCAL_PORT' $ss_local_port /script/iptables.sh

cp ./script/iptables.sh /jffs/scripts/
cp ./script/iptables-ch.sh /jffs/scripts/
echo -e "#!/bin/sh\n\n/jffs/scripts/iptables.sh" > /jffs/scripts/wan-start
chmod a+rx /jffs/scripts/*

echo 'Deploy success! Rebooting, please wait ...'