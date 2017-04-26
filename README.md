# ASUS Merlin 路由器科学上网

## 准备工作

1. 一台刷上 ASUS Merlin 的华硕路由器，我使用的是 ASUS RT-AC68U。

2. Shadowsocks 服务端，需启用 UDP Relay。使用 Docker 部署，可以看[docker-compose.yml](https://github.com/xzdbd/dockerfiles/blob/master/shadowsocks-go/docker-compose.yml)。

##　实现思路

1. 海外流量走 Shadowsocks，国内流量直连。

2. 海外域名的 DNS 请求通过 Shadowsocks 转发到 VPS 上返回。

3. 两端开启 [kcptun](https://github.com/xtaci/kcptun) 加速。（可选）

##　具体步骤

### 给路由器刷 merlin 固件。

Asuswrt是华硕公司为他的路由器所开发的固件。Asuswrt-merlin是一个对Asuswrt固件二次开发进行各种改进和修正的项目。源代码在这里：[https://github.com/RMerl/asuswrt-merlin](https://github.com/RMerl/asuswrt-merlin)

Merlin固件拥有更多的功能，由于第三方不断维护代码，各种新功能也在不断增加。Merlin固件的升级并不需要反复的操作过程，方法与官方固件的升级相同，有很好的硬件软件兼容性。继承了Asuswrt官方固件优秀的交互界面。

**1）下载固件**。先到 [https://asuswrt.lostrealm.ca/download](https://asuswrt.lostrealm.ca/download) 下载相应的固件，并解压。（我下载的是 `RT-AC68U_380.65_4.zip` ）

**2）升级固件**。登录到你的路由器后台 `http://192.168.1.1/` ，在 `系统管理` -> `固件升级` 中上传固件文件（我上传的是：`RT-AC68U_380.65_4.trx`）

**3）打开 JFFS 分区**。`系统管理` -> `系统设置` -> `Persistent JFFS2 partition`

- `Format JFFS partition at next boot` - `是`
- `Enable JFFS custom scripts and configs` - `是`

**4）打开 ssh 登录**。 `系统管理` -> `系统设置` -> `SSH Daemon` 

- `Allow SSH password login` - `是`

**5）重启路由器**。确保再次进来时, Format JFFS partition at next boot 选项已经恢复成`否`。

### 格式化 U 盘

格式化 U 盘到 ext3 分区。假设 U 盘驱动器设备为 /dev/sda1 。

```
# mkfs.ext3 /dev/sda1
```

### 安装Entware-ng

ssh登陆到路由器。

```
ssh admin@192.168.1.1
```

安装Entware-ng，具体的安装说明看Entware-ng的[Wiki](https://github.com/Entware-ng/Entware-ng/wiki/Install-on-asuswrt-merlin-firmware)。

```
entware-setup.sh
```

提示选择 U 盘分区时，选择之前格式化的 U 盘，一般选择 1 。

测试 opkg 包管理是否正常可用，安装后续操作需要用到的 vim 。

```
opkg install vim
```

### 安装配置 Shadowsocks

首先安装 shadowsocks-libev

```
opkg install shadowsocks-libev
```

修改 shadowsocks 配置文件 ``/opt/etc/shadowsocks.json``

```
{
    "server":"SS-SERVER-IP",
    "server_port":8389,
    "local_address":"192.168.1.1",
    "local_port":1080,
    "password":"password",
    "timeout":60,
    "method":"aes-128-cfb"
}
```

其中 local_address 参数：

	* 要想使局域网内机器能够访问到部署在路由器上的 shadowsocks 服务，需要将该地址指定为路由器的IP地址（如 192.168.1.1，具体值取决于所配置的路由器的IP地址）；
	
	* 要想使路由器自身的流量能够经过 shadowsocks 服务，需要将该地址指定为 127.0.0.1；

	* 若想使路由器自身和局域网内的机器都能够使用到 shadowsocks 服务，则需将该地址指定为 0.0.0.0。

编辑 S22shadowsocks 服务文件 ``/opt/etc/init.d/S22shadowsocks``，将其中PROCS=ss-local改为PROCS=ss-redir。

```
#!/bin/sh

ENABLED=yes
PROCS=ss-redir
ARGS="-c /opt/etc/shadowsocks.json"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
```

启动S22shadowsocks：``/opt/etc/init.d/S22shadowsocks start``。

### 配置 ss-tunnel 作为 DNS 解析转发

新建 S22ss-tunnel 服务文件 ``/opt/etc/init.d/S22ss-tunnel``

```
#!/bin/sh

ENABLED=yes
PROCS=ss-tunnel
ARGS="-c /opt/etc/shadowsocks.json -b 127.0.0.1 -l 7913 -L 8.8.8.8:53 -u"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
```

ss-tunnel 建立了一个通道，发到这个 7913 端口的请求都会被转到 VPS，VPS 再去请求 Google DNS (8.8.8.8) 做 DNS 解析。

启动S22shadowsocks：``/opt/etc/init.d/S22ss-tunnel start``。

### 配置 iptables 做自动流量转发

具体思路：

	** 到内网的流量（如 127.0.0.1, 192.168.1.*) 直连

	** 到国内 ISP 的流量直连

	** 到 VPS 的流量直连

	** 其他流量都转到 VPS 上

```
#!/bin/sh

if $iptables -t nat -N SHADOWSOCKS; then
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
```	

其中：
	
	** ``SS-SERVER-IP`` 改为 Shadowsocks 服务端所在机器的IP

	** ``SS-LOCAL-PORT`` 改为 本地监听 Shadowsocks 的端口，本例中为 1080

	** ``/jffs/scripts/iptables-ch.sh`` 脚本为使用 bestroutetb 生成国内 IP 段的 iptables

		```
		$ bestroutetb -p custom --rule-format="iptables -t nat -A SHADOWSOCKS -d %prefix/%mask -j %gw"$'\n'  --gateway.net="RETURN" -o ./iptables
		$ grep RETURN ./iptables > ./iptables-ch.sh
		```

将 iptables.sh 以及 iptables-ch.sh 脚本拷贝到路由器 ``/jffs/scripts/`` 路径下，并修改或修改 /jffs/scripts/nat-start 脚本。该脚本用来设置nat表有关规则。有关 nat-start 脚本，参考 [asuswrt-merlin wiki](https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts)。

```
#!/bin/sh

/jffs/scripts/iptables.sh

```

### 动态DNS配置

使用 [dnsmasq-china-list](https://github.com/felixonmars/dnsmasq-china-list) 项目中提供的(accelerated-domains.china.conf) 作为 DNS 白名单。 所有在白名单中的域名, 跳过代理, 剩下的通过代理访问, 可参阅 foreign_domains.conf.

```
mkdir /jffs/dnsmasq-conf
wget -O /jffs/dnsmasq-conf/ https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf

# 此处7931端口要与之前配置的ss-tunnel监听端口一致
echo server=/#/127.0.0.1#7913 > /jffs/dnsmasq-conf/foreign-domains.conf

echo conf-dir=/jffs/dnsmasq-conf > /jffs/configs/dnsmasq.conf.add
```


### 配置调度任务

在脚本 ``/jffs/scripts/service-start`` 中加入以下脚本以检查各项服务是否正在行，以及iptables设置是否正常被应用。[Wiki](https://github.com/RMerl/asuswrt-merlin/wiki/Scheduled-tasks-(cron-jobs))

```
# asuswrt-merlin 有时候会清空 iptables 的 NAT 表, 因此让 iptables.sh 一分钟定时执行一次.
cru a iptables-nat "*/1 * * * *" "/jffs/scripts/iptables.sh"

# 每隔 1 分钟检测下所有的服务是否运行.
cru a run-services "*/1 * * * *" "/jffs/scripts/services-start"
```

### 以上各项完成后，重启路由器，访问网站，查看路由器已经正常运行。如果出现域名系统(DNS) 错误，尝试清楚浏览器 DNS 缓存以及电脑/手机 DNS 缓存。


### 开启 [kcptun](https://github.com/xtaci/kcptun) 加速 （可选）

当 Shadowsocks 本身连接速度不理想时，可以考虑使用kcptun。

**1. 架设 kcptun 服务端：** 具体查看kcptun主页。这里假设 kcptun 服务端监听4000端口。

**2. 运行 kcptun 客户端：** 

下载 kcptun 最新 [release](https://github.com/xtaci/kcptun/releases)，需要根据路由器 CPU 架构来选择 arm 或者 mips 。

```
wget -O /opt/etc/ https://github.com/xtaci/kcptun/releases/download/v20170329/kcptun-linux-arm-20170329.tar.gz
tar xzvf opt/etc/kcptun-linux-arm-20170329.tar.gz -C /opt/bin/
```

新建 kcptun 配置文件 ``/opt/etc/kcptun-router.json`` 。参数根据需要进行调整。KCPTUN-SERVER-ADDRESS 改为 kcptun 服务端的 IP 。

```
{
"localaddr": "127.0.0.1:8389",
"remoteaddr": "KCPTUN-SERVER-ADDRESS:4000",
"key": "1234567890",
"crypt": "salsa20",
"mode": "manual",
"conn": 1,
"mtu": 1400,
"sndwnd": 128,
"rcvwnd": 1024,
"datashard": 0,
"parityshard": 0,
"dscp": 46,
"nocomp": true,
"acknodelay": false,
"nodelay": 0,
"interval": 20,
"resend": 2,
"nc": 1,
"sockbuf": 4194304,
"keepalive": 10
}
```

新建 S22kcptun 服务脚本 ``/opt/etc/init.d/S22kcptun``

```
#!/bin/sh

ENABLED=yes
PROCS=client_linux_arm5
ARGS="-c /opt/etc/kcptun-router.json"
PREARGS=""
DESC=$PROCS
PATH=/opt/sbin:/opt/bin:/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

. /opt/etc/init.d/rc.func
```

运行 kcptun 服务

```
/opt/etc/init.d/S22kcptun start
```

**3. 修改 /opt/etc/shadowsocks.json 文件，

```
{
    "server":"127.0.0.1",
    "server_port":8389,
    "local_address":"192.168.1.1",
    "local_port":1080,
    "password":"password",
    "timeout":60,
    "method":"aes-128-cfb"
}
```

其中，server 参数修改为 127.0.0.1，server_port 参数需要对应 kcptun 客户端的本地监听端口。

## 参考文档

[使用华硕 merlin 架设透明代理](https://github.com/zw963/asuswrt-merlin-transparent-proxy)

[使用 Asus Merlin 实现路由器翻墙](https://github.com/onlyice/asus-merlin-cross-the-gfw)

[在路由器上部署 shadowsocks](https://zzz.buzz/zh/gfw/2016/02/16/deploy-shadowsocks-on-routers/)

[VPN 科学上网](https://haoel.github.io/)

[kcptun](https://github.com/xtaci/kcptun/blob/master/README.md)

[asuswrt-merlin firmware](https://github.com/RMerl/asuswrt-merlin)
