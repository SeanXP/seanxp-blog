---
title: shadowsocks
date: 2016-05-08T11:30:12+08:00
tags: ["Tutorial", "Internet", "Linux", "Efficiency", "Software"]
categories: ["Tutorial"]
draft: false
---


<blockquote class="blockquote-center"> Across the Great Wall we can reach every corner in the world.
「越过长城，走向世界每个角落」
中国互联网发送的第一封电子邮件（1987年）
</blockquote>

<!--more-->

# 写给非专业人士看的 Shadowsocks 简介
原文: https://vc2tea.com/whats-shadowsocks/

## long long ago ...
![shadowsocks-1](/images/2016/shadowsocks-1.png)
在很久很久以前，我们访问各种网站都是简单而直接的，用户的请求通过互联网发送到服务提供方，服务提供方直接将信息反馈给用户。

## when evil comes
![shadowsocks-2](/images/2016/shadowsocks-2.png)
然后有一天，GFW 就出现了，他像一个收过路费的强盗一样夹在了在用户和服务之间，每当用户需要获取信息，都经过了 GFW，GFW将它不喜欢的内容统统过滤掉，于是客户当触发 GFW 的过滤规则的时候，就会收到 Connection Reset 这样的响应内容，而无法接收到正常的内容。
> 国家公共网络监控系统，俗称中国网络防火墙（The Great Fire Wall of China，常用简称“GFW”或“墙”）。一般意义所説的GFW，主要指中国官方对境外涉及敏感内容的网站、IP地址、关键词、网址等的过滤。随着使用的拓广，中文“墙”和英文“GFW”有时也被用作动词，网友所説的“被墙”即指被防火长城所屏蔽。

参考(墙外): [道高一尺，墙高一丈：互联网封锁是如何升级的](https://theinitium.com/article/20150904-mainland-greatfirewall/)

## ssh tunnel
聪明的人们想到了利用境外服务器代理的方法来绕过 GFW 的过滤，其中包含了各种HTTP代理服务、Socks服务、VPN服务...
其中以 ssh tunnel 的方法比较有代表性:
![shadowsocks-3](/images/2016/shadowsocks-3.png)
* 1) 首先用户和境外服务器基于 ssh 建立起一条加密的通道;
* 2,3) 用户通过建立起的隧道进行代理，通过 ssh server 向真实的服务发起请求;
* 4,5) 服务通过 ssh server，再通过创建好的隧道返回给用户;

![shadowsocks-5](/images/2016/shadowsocks-5.png)
![shadowsocks-6](/images/2016/shadowsocks-6.png)
由于 ssh 本身就是基于 RSA 加密技术，所以 GFW 无法从数据传输的过程中的加密数据内容进行关键词分析，避免了被重置链接的问题，但由于创建隧道和数据传输的过程中，ssh 本身的特征是明显的，所以 GFW 一度通过分析连接的特征进行干扰，导致 ssh 存在被定向进行干扰的问题。
## shadowsocks
于是 [clowwindy](https://github.com/shadowsocks/shadowsocks) 分享并开源了他的解决方案 - [shadowsocks](https://shadowsocks.org/)。
简单理解的话，shadowsocks 是将原来 ssh 创建的 Socks5 协议拆开成 server 端和 client 端，所以下面这个原理图基本上和利用 ssh tunnel 大致类似：
![shadowsocks-4](/images/2016/shadowsocks-4.png)
* 1,6) 客户端发出的请求基于 Socks5 协议跟 ss-local 端进行通讯，由于这个 ss-local 一般是本机或路由器或局域网的其他机器，不经过 GFW，所以解决了上面被 GFW 通过特征分析进行干扰的问题;
* 2,5) ss-local 和 ss-server 两端通过多种可选的加密方法进行通讯，经过 GFW 的时候是常规的TCP包，没有明显的特征码而且 GFW 也无法对通讯数据进行解密;
* 3,4) ss-server 将收到的加密数据进行解密，还原原来的请求，再发送到用户需要访问的服务，获取响应原路返回;

# Shadowsocks 使用
Shadowsocks分为服务器与客户端两部分程序, 其正常使用需要服务端(其实所有的翻墙方式都需要服务端)，搭建服务端需要你拥有一个属于自己的VPS(或者直接购买其他人提供的Shadowsocks服务器帐号)。服务器端程序一般运行在国外的主机即可。
## 搭建Shadowsocks服务器
* [github - shadowsocks](https://github.com/shadowsocks)
* [史上最详尽Shadowsocks从零开始一站式翻墙教程](https://shadowsocks.blogspot.com/2015/01/shadowsocks.html)
* [shadowsocks – libev 服务端的部署](https://cokebar.info/archives/767)
* [Shadowsocks指导篇](https://doub.io/ss-jc26/)
* [Shadowsocks libev一键安装脚本](https://doub.io/ss-jc5/)

### VPS主机选购
注意：这些VPS服务商网址在部分地区被墙(DNS污染)，需要翻墙访问。不过在上面购买的VPS不受影响（IP直接访问）。
* [DigitalOcean](https://www.digitalocean.com/)
    KVM架构，512MB/1CPU，20GB SSD Disk，1TB流量/月，$5/month($0.007/hour)（折合人民币30元/月）
    我个人就是使用[DigitalOcean](https://www.digitalocean.com/)的VPS($5/month)，作为Shadowsocks服务器绰绰有余。
    推介计划：点击[推介地址](https://m.do.co/c/0ffb835591de)注册DigitalOcean帐号，可以立即到帐$10用于试用；
* [搬瓦工(BandwagonHOST)](https://bandwagonhost.com/)
    OpenVZ架构，256MB内存，10GB硬盘，500GB流量/月，19.99美元/年（折合人民币10元/月）
    OpenVZ架构，512MB内存，20GB硬盘，1TB流量/月，49.99美元/年（折合人民币25元/月）
* [Linode](https://www.linode.com/)
    Xen架构，1GB内存，24GB硬盘，2TB流量/月，10美元/月（折合人民币60元/月）
    只推荐给对连接速度和网络延迟有极致追求的用户，一般DigitalOcean或BandwagonHOST足以满足一般翻墙要求。
* [gubo.org - VPS推荐](https://www.gubo.org/reliable-vps-providers/)
* [搬瓦工19.9刀QN机房双向CN2年付VPS](https://xiaozhou.net/bandwagonhost_annual_pay_vps_stock_refreshed-2018-01-29.html)
* [Google Cloud Platform](https://cloud.google.com/)

DigitalOcean和搬瓦工两家的VPS都支持PayPal付款，DigitalOcean也可以选择在账单里绑定信用卡进行支付。
Linode只能使用信用卡支付，官方会随机手工抽查，被抽查到的话需要上传信用卡正反面照片以及可能还需要身份证正反面照片，只要材料真实齐全，审核速度很快，一般一个小时之内就可以全部搞定。账户成功激活以后，就可以安心使用了。

> OpenVZ为不完全虚拟化技术，每个VPS账户共享母机内核，易受同一母机下其他VPS的影响，几乎不能单独修改内核。Xen和KVM为完全虚拟化技术，各VPS之间互相独立，基本互不影响，而且可以任意修改内核。
> 这三种架构对我们搭建shadowsocks服务器来讲最直观的区别就是，Xen和KVM可通过系统内核修改来优化服务器，大幅度提升shadowsocks的连接速度，尤其体现在晚高峰的时候。

### 在VPS中搭建Shadowsocks服务器端程序
充值完毕后，就可以通过网页操作创建对应的虚拟机映像，开启虚拟机映像后，根据其IP、SSH端口、root密码，就可以在任意一台电脑上远程登录VPS。
windows推荐使用putty登录, Linux直接通过命令行ssh工具登录:

    $ ssh root@192.168.1.100 -p 22

* Shadowsocks Server下载地址: https://shadowsocks.org/en/download/servers.html
* Shadowsocks Server [README.md](https://github.com/shadowsocks/shadowsocks/blob/master/README.md)

#### Install

2017/02/18 更新：[Shadowsocks libev一键安装脚本](https://doub.io/ss-jc5/) 可以一键快速安装 shadowsocks libev。

Debian / Ubuntu:

    apt-get install python-pip
    pip install shadowsocks

CentOS:

    yum install python-setuptools && easy_install pip
    pip install shadowsocks

#### Usage

    ssserver -p 443 -k password -m aes-256-cfb

To run in the background:

    sudo ssserver -p 443 -k password -m aes-256-cfb --user nobody -d start

To stop:

    sudo ssserver -d stop

To check the log:

    sudo less /var/log/shadowsocks.log

#### Arch Linux - Install Shadowsocks Server

    $ sudo pacman -S git python2
    $ python2 --version
    Python 2.7.11
    $ git clone -b master https://github.com/shadowsocks/shadowsocks
    $ cd shadowsocks/shadowsocks
    $ sudo python server.py -p 8388 -k password -m aes-256-cfb

* `-p`, 设定server_port;
* `-k`, password;
* `-m`, 加密方式;

#### Ubuntu - Install Shadowsocks Server
shadowsocks-python is the initial version written by @clowwindy. It aims to provide a simple-to-use and easy-to-deploy implementation with basic features of shadowsocks.
First, make sure you have Python 2.6 or 2.7.

    $ python --version
    Python 2.7.6
    $ sudo pip install shadowsocks
    $ ssserver -p 8388 -k password -m aes-256-cfb

#### 添加配置文件 shadowsocks.json

    $ sudo vim /etc/shadowsocks.json
`/etc/shadowsocks.json`:

    {
        "server":"0.0.0.0",
        "server_port":8388,
        "local_port":1080,
        "password":"barfoo!",
        "timeout":600,
        "method":"aes-256-cfb",
        "auth": true
    }
Shadowsocks Server配置信息:
* `server`:       Shadowsocks Server IP, VPS的IP或Shadowsocks服务器IP;
* `server_port`:  Shadowsocks Server Port;
* `local_port`:   Local Proxy Port, 本地代理地址，其他应用程序想要通过SOCKS 5通道上网，就在其他应用程序的代理设置该端口，一般为`(127.0.0.1:1080)`;
* `password`:     Shadowsocks Server Encrypt Transfer Password;
* `timeout`:      Connections timeout in seconds;
* `method`:       encryption method, "bf-cfb", "aes-256-cfb", "des-cfb", "rc4", etc.
    Default is table, which is not secure. "aes-256-cfb" is recommended.
* `auth`:         one-time authentication, set true to enable one-time authentication feature.

Linux - Shadowsocks Server:

    # 通过pip install安装shadowsocks, 则:
    $ /usr/bin/python /usr/bin/ssserver -c /etc/shadowsocks.json

    # 或者, 通过git clone下在shadowsocks, 则:
    $ sudo python2 /home/sean/shadowsocks/shadowsocks/server.py -c /etc/shadowsocks.json

#### 用supervisord管理python进程，实现开机自动启动Shadowsocks服务器程序
Supervisor 是基于 Python 的进程管理工具，只能运行在 Unix-Like 的系统上，也就是无法运行在 Windows 上。Supervisor 官方版目前只能运行在 Python 2.4 以上版本，但是还无法运行在 Python 3 上，不过已经有一个 Python 3 的移植版 supervisor-py3k。

    # Arch Linux
    $ sudo pacman -S supervisor
    $ sudo su - root -c "echo_supervisord_conf > /etc/supervisord.conf"

    # Ubuntu
    $ sudo pip install supervisor
    $ sudo su - root -c "echo_supervisord_conf > /etc/supervisord.conf"

并在`/etc/supervisord.conf`下添加:

    [program:shadowsocks]
    command=ssserver -c /etc/shadowsocks.json
    autostart=true
    autorestart=true
    user=root
    log_stderr=true
    logfile=/var/log/shadowsocks.log

配置开机启动supervisord, 如果是Ubuntu/CentOS, 则在`/etc/rc.local`里添加:

    # 如果是 Ubuntu 添加以下内容
    /usr/local/bin/supervisord -c /etc/supervisord.conf

    # 如果是 Centos 添加以下内容
    /usr/bin/supervisord -c /etc/supervisord.conf

若为Arch Linux, 则在Shell运行:

    $ sudo systemctl enable supervisord

参考: [Python 进程管理工具 Supervisor 使用教程](https://www.restran.net/2015/10/04/supervisord-tutorial/)
###  shadowsocks 公共代理的必要设置
参考: [shadowsocks 公共代理的必要设置](https://www.atgfw.org/2015/02/shadowsocks_10.html)
建议不要把自己的Shadowsocks帐号共享给太多人。「不要把人想得太好，但也不要把人想得太坏，都是凡人。」
个人租用VPS并部署shadowsocks服务器端，个人流量较小，也不易被GFW注意到。很多翻墙软件的特点是公共代理，很多人使用，当很多墙内客户端都在短时间内（或者说同时）长时间连接到一个或几个国外远程服务器上时，就会引起GFW的注意并被很快封杀。VPS的IP被封杀的话，就需要重新创建一个虚拟机镜像或切换机房。
如果非要作为公共代理，建议设置以下几点：
* 超时时间越长，连接被保持得也就越长，导致并发的tcp的连接数也就越多。对于公共代理，这个值应该调整得小一些。推荐60秒。
* 在VPS上检查最大文件描述符数量`$ ulimit -n`, 公共代理需要更多并发的TCP连接数，`# ulimit -n 8000`提高限制。ulimit的设置是一次性的，每次启动ss-server之前都要设置一下。
* 只要shadowsocks被公开出去，肯定会有人拿代理用于暴力破解ssh的密码。推荐你把shadowsocks限制为只允许访问443和80两个端口。如果你不添加这样的限制，很多vps商都会因为ssh连接开得太多而暂停对你的服务。
具体做法: 让ss-server以特定的用户启动

        $ sudo adduser http-ss
        $ su http-ss -c "ssserver -s 0.0.0.0 -p 443 -k password -m aes-256-cfb -d"

        # 对于http-ss用户，限制其不能访问80,443之外的端口
        $ sudo iptables -t filter -A OUTPUT -d 127.0.0.1 -j ACCEPT
        $ sudo iptables -t filter -m owner --uid-owner http-ss -A OUTPUT -p tcp --sport 1080 -j ACCEPT
        $ sudo iptables -t filter -m owner --uid-owner http-ss -A OUTPUT -p tcp --dport 80 -j ACCEPT
        $ sudo iptables -t filter -m owner --uid-owner http-ss -A OUTPUT -p tcp --dport 443 -j ACCEPT
        $ sudo iptables -t filter -m owner --uid-owner http-ss -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
* 避免shadowsocks帐号被用于bt下载（美国的DMCA版权法律），对80端口的流量再进一步进行限制（下载nginx并限制流量）。

## 购买Shadowsocks服务器帐号
除了自己选购VPS(需要一定的Linux运维能力)，也可以直接使用别人搭建好的VPS与Shadowsocks服务器。
我个人使用过[shadowsocks.com](https://portal.shadowsocks.com/aff.php?aff=2104)的服务器，提供有：
* Shadowsocks.com 普通版 - $15.95USD (同一时间同一个账号仅限一个终端使用)
* Shadowsocks.com 高级版 - $63.95USD (同一个账号同时支持 5 个终端使用)

注意，shadowsocks.com不是官方网址，而是一个帐号提供商，不具有权威性，官方网址为[shadowsocks.org](https://shadowsocks.org/);
类似的帐号提供商还有很多，其他我没用过的就不发布评论，大家可以自行Google搜索。
## 配置Shadowsocks客户端
Shadowsocks Client下载地址: https://shadowsocks.org/en/download/clients.html
无论是自己搭建Shadowsocks服务器，还是使用别人提供的服务器，最后都还需要在自己的电脑上运行Shadowsocks客户端，连接服务器，才可以科学上网。

* 客户端可以使用不同平台的GUI版本，优点是使用方便，可以随时启动关闭，随时切换服务器。
* 也可以使用通用的命令行版本，优点是同一个程序在各个平台编译后就可以使用，占用资源更小，软件更新速度快。

### 客户端 - GUI版
下载对于平台的GUI客户端，运行之后，要添加server相关信息(server, server_port, password, method...);

        服务器：你的VPS IP地址（非0.0.0.0）
        远程端口：8388
        本地端口：1080
        密码：yourpassword
        加密方法：AES-256-CFB
        路由：绕过局域网及中国大陆地址
        全局代理：勾选
        UDP转发：建议勾选，如有问题则取消勾选
        自动连接：勾选
#### Shadowsocks for OSX
For OS X, use [Homebrew](https://brew.sh) to install or build.
Install Homebrew:
```bash
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
Install Shadowsocks:
```bash
brew cask install shadowsocksx
```
Shadowsocks for OSX可以正常使用，但是已经一年多没有维护了（[@clowwind](https://github.com/clowwindy) 由于政策原因不再维护）。

### 客户端 - CLI版

#### Intro

[shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev) is a lightweight secured SOCKS5 proxy for embedded devices and low-end boxes.
It is a port of [Shadowsocks](https://github.com/shadowsocks/shadowsocks) created by [@clowwindy](https://github.com/clowwindy), which is maintained by [@madeye](https://github.com/madeye) and [@linusyang](https://github.com/linusyang).

#### Features

Shadowsocks-libev is written in pure C and only depends on [libev](https://software.schmorp.de/pkg/libev.html) and [OpenSSL](https://www.openssl.org/) or [PolarSSL](https://polarssl.org/). The use of [mbedTLS](https://tls.mbed.org/) is added but still for testing, and it is not officially supported yet.
In normal usage, the memory footprint is about 600KB and the CPU utilization is no more than 5% on a low-end router (Buffalo WHR-G300N V2 with a 400MHz MIPS CPU, 32MB memory and 4MB flash).
For a full list of feature comparison between different versions of shadowsocks, refer to the [Wiki page](https://github.com/shadowsocks/shadowsocks/wiki/Feature-Comparison-across-Different-Versions).

#### Usage
由于 Shadowsocks-libev 良好的通用性，建议使用 Shadowsocks-libev ，任何平台都可以使用。Shadowsocks-libev提供的命令行工具：`ss-[local|redir|server|tunnel]`，其中`ss-server`用于搭建shadowsocks服务器，`ss-local`用于连接服务器。命令的使用与上面的`ssserver`相同，不过这个是C语言版本实现的。
`shadowsocks.json`的格式同服务器的配置文件，需要修改的就是`server`部分，不再是`0.0.0.0`，而是一个可以ping通的IP地址。

    ss-local -c shadowsocks.json

### 本地SOCKS 5代理（必须配置！）
**打开客户端并不意味着就可以翻墙？！**
shadowsocks client只是打开本地的`local_port`开始监听，发往`local_port`的数据会发往`server`，以实现翻墙代理。没有发往`local_port`的数据，是无法翻墙的。
因此，对于本地需要翻墙的应用，例如Chrome，Dropbox等，必须要在各自应用的配置选项中，找到代理`Proxy`选项，选择`SOCKS 5`代理选项，并填写:`代理IP 127.0.0.1`, `端口 1080`。

## TCP BBR
[开启TCP BBR拥塞控制算法](https://github.com/iMeiji/shadowsocks_install/wiki/%E5%BC%80%E5%90%AFTCP-BBR%E6%8B%A5%E5%A1%9E%E6%8E%A7%E5%88%B6%E7%AE%97%E6%B3%95)
[Debian/Ubuntu TCP拥塞控制技术 ——TCP-BBR 一键安装脚本](https://doub.io/wlzy-16/)
BBR 目的是要尽量跑满带宽, 并且尽量不要有排队的情况, 效果并不比速锐差。最新 4.9 内核已支持 tcp_bbr，需要将 VPS linux kernel 更新至 4.9 以上版本才可。
开启前后可通过 youtube 视频（右键：详细统计信息）检测网速前后的改善效果。

# 匿名与信息安全
[翻墙与匿名与信息安全科普文链接集合](https://www.chinagfw.org/2015/02/ghost-assassin_10.html)
## 翻墙手段(安全度有高到低)
1. I2P： 安全性最强的匿名软件，没有之一，但是速度极慢，基本上不是人能忍受的，[配置教程](https://program-think.blogspot.com/2012/06/gfw-i2p.html)。
2. TOR：大名鼎鼎的洋葱路由，令NSA头大，实质是动态三重代理，推荐[TOR+前置代理组合](https://plus.google.com/109790703964908675921/posts/QqZ1z7akz6Q)。
3. shadowsocks：一个轻量级socks加密代理，全主流平台支持。
简单来说，shadowsocks就是一个一重加密socks代理，本机上的客户端先与远程服务器（配置了shadowsocks服务端程序的VPS）端建立连接，远程服务器再与目标网站连接从而成功翻墙。
首先，VPN无法进行远程DNS解析，所以很多时候在使用VPN的同时还要设定好一个国外的DNS服务器才能正常翻墙（很多人反映很多时候挂着VPN都无法正常打开FB，推特等网站，其实就是因为没有设定国外DNS服务器而遇到了DNS污染）；
而shadowsocks默认就支持远程DNS解析（因为socks5代理支持远程DNS解析），这样就省去了配置国外DNS服务器的麻烦，同时还防止了信息泄露：DNS查询直接递给远程代理服务器，然后通过墙外DNS服务器查询得到结果再传回客户端，这样ISP就无法通过DNS查询知道你访问了哪个网站了（而不支持远程DNS解析的VPN就留下了泄露访问信息的隐患），同时也避开了DNS污染。
4. VPN：VPN启动后一直是全局代理，不方便浏览墙内网站。不要相信墙内存活的VPN服务商。一旦涉及到付费这一环节，你就很容易被追踪到。所有的VPN都能成为TOR的前置代理。
5. Lantern：
    * 1.X版本）建立在脆弱的Gtalk服务上，以对等网络P2P的形式翻墙，提供了一种用户可信赖的节点绕过互联网封锁，安全性没有保障(加密机制较弱, 固定端口的传输模式极易受到 GFW 的判定后遭到封杀, Lantern客户端在运行时还会公布出连接服务器的具体IP地址，这一做法会直接招致GFW的封杀和屏蔽)。有了 Lantern，每一台电脑都可以变成服务器。通过运行 Lantern，每一个拥有不受审查的网络的用户可以为那些没有条件的用户提供连接，以此来提供连接到被审查网站（如 Twitter、Facebook 和YouTube）的途径。Lantern的P2P结构抵抗审查是建立在用户信任链基础上的。如果你邀请的朋友不小心邀请了GFW工作人员，你的代理节点也被封锁。
    * 2.X版本）2015年，蓝灯推出2.0版，用户不再需要通过邀请来连接，且使用网页UI代替客户端式的设置方式。2.X版本不再使用1.X版时的P2P模式，而是使用代理服务器的模式。
    * [初窥万花筒，浅析Lantern背后的Kaleidoscope设计](https://bitinn.net/10629/) Lantern的定位是P2P网络封锁突破工具，以其“通过信任圈子”传播服务信息的特色作为主要卖点，对抗见洞插针（probing）的防火墙系统。核心技术Kaleidoscope是一个P2P中继系统，主要用途是让被封锁网络域内的用户能访问到被封锁的内容。换而言之，Kaleidoscope的主要目的就是突破网络内容封锁，而非匿名或传输安全性。后者分别是Tor与VPN的主要特性。
6. GAE类翻墙工具, 不原生支持HTTPS（也就是说无法成为TOR的前置代理），无法防范中间人攻击，加密程度不高（早期无加密），安全性很低，建议只用来浏览网页。[GAE类翻墙软件的风险](https://plus.google.com/109790703964908675921/posts/QqZTB5EdLEV)
7. 修改hosts与躲避DNS污染：毫无安全性可言，目标网站可以看到你的真实公网IP，但速度最快。

推荐：[TOR+前置代理](https://plus.google.com/109790703964908675921/posts/LyWo2agoau3)

## 保护和慎用匿名、假名的权利
[保护和慎用匿名、假名的权利 - 徐贲](https://blog.sina.com.cn/s/blog_4cacf1f30102ecwu.html)

* 在你失去匿名之前，你不会知道它有多么可贵。匿名是一种个人的隐私权，是不想让人知道你是谁的时候，有法律在保护你不让别人知道。
* 目前网络上的言论发表，使用的大多是匿名和假名，允许使用匿名和假名应该成为维护互联网言论自由空间的一个重要条件。从平衡个人隐私、公众言论责任和公民伦理着眼，网络实行“有限实名制”，即“后台实名，前台匿名”，要比强制性禁止匿名或假名更符合白皮书的精神。
* 有必要区别网络上的匿名和假名（用笔名），匿名和假名与实名（真名）的关系是不同的。“匿名”（anonymity）一词原意是“没有名字”或“无名”。 匿名是把真实姓名藏匿起来，变得“无名”。
* 在一个正常的公共社会里，匿名和假名与实名（真名）一样，有它们的身份标志功能，需要具体地看待，不可一概而论地偏废。

# 后记

之所以写这篇博客，有以下几点：
* 一是整理之前看到的科学上网攻略；作为一名互联网爱好者，热衷于获取自由的互联网信息并将其实践到实际生活中。
* 二是帮助需要科学上网的同学梳理思路，简介科学上网的大致流程。科学上网并不难，墙也并不可怕。热爱自由的思想是不怕子弹的，可怕的是一个国家的人民固步自封而又妄自尊大，可怕的是人民无知而又对其“无知”而无知。古有百家争鸣亦有焚书坑儒，近有闭关自守又有戊戌变法。书犹药也，善读之可以医愚，以史为鉴，自强不息。
* 三是悼念一位学弟([青年魏则西之死](https://www.ifanr.com/651797))，天下熙熙皆为利来，天下攘攘皆为利往，我也不想评论百度、医院、监管、政策的是非曲直，历史自有定论。我只是希望作为当代大学生，可以在喧嚣的互联网时代学会保护自己，扩大知识普及，减少信息不对称，避免下一个因为无知而再次发成的悲剧，并且尽我所能去帮助他人(To grow and to help others grow. To live and to help others live.)。

<blockquote class="blockquote-center">
我向来是不惮以最坏的恶意，来推测中国人的，然而我还不料，也不信竟会下劣凶残到这地步。况且始终微笑着的和蔼的刘和珍君，更何至于无端在府门前喋血呢？
惨象，已使我目不忍视了；流言，尤使我耳不忍闻。我还有什么话可说呢？我懂得衰亡民族之所以默无声息的缘由了。沉默呵，沉默呵！不在沉默中爆发，就在沉默中灭亡。
苟活者在淡红的血色中，会依稀看见微茫的希望；真的猛士，将更奋然而前行。
鲁迅《记念刘和珍君》
</blockquote>
