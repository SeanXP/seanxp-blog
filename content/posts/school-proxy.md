---
title: 内网穿透校园网搭建 IPv6 代理
date: 2018-08-12T14:18:07+08:00
tags:
  - Linux
  - 计算机网络
  - 网络代理
  - 大学
categories:
  - 网络技术
draft: false
---
<div align=center>
<img src="https://image.seanxp.com/school-proxy/0.jpg" alt='proxy'/>
<blockquote class="blockquote-center">那时我们有梦，关于校园网，关于种子，关于穿越高校的 IPv6，
    如今下班后的我们深夜饮酒，杯子碰到一起，都是梦破碎的声音。
</blockquote>
</div>

<!--more-->
<div align=center>
<img src="https://image.seanxp.com/school-proxy/1.jpg" width="400" height="400" alt='NAT'/>
</div>
* [wiki-网络地址转换](https://www.wikiwand.com/zh-hans/%E7%BD%91%E7%BB%9C%E5%9C%B0%E5%9D%80%E8%BD%AC%E6%8D%A2)

由于 IPv4 地址的不足，网络地址转换（Network Address Translation，NAT）被普遍应用来解决更多设备与更少 IP 间的矛盾，NAT 成了家庭和小型办公室网络连接上的路由器的一个标准特征，因为对他们来说，申请独立的IP地址的代价要高于所带来的效益。

使用路由器组建局域网 LAN，LAN 网络内的设备分配保留内网保留 IP 地址（private IP），只有路由器网关具有访问互联网的公网 IP（public IP）。随之而来的是各种 LAN 防火墙、代理等。在解决 IPv4 地址不足分配问题的同时，NAT也让主机之间的通信变得复杂，导致了通信效率的降低。

* NAT可以同时让多个计算机同时联网，并隐藏其内网IP，因此也增加了内网的网络安全性；
* NAT对来自外部的数据查看其NAT映射记录，对没有相应记录的数据包进行拒绝，提高了网络安全性；
* NAT设备会对数据包进行编辑修改，这样就降低了发送数据的效率；

校园网就是高校专用的局域网，校园网内部是局域网，学校有总机与外部联网。一般都具有防火墙，即使校园网内的服务器分配的是公网 IP，校园网防火墙也会拒绝掉所有主动请求后端服务器的请求来源，只允许服务器主动对外建立连接。

校园网网速快，尤其是在下载 BT/PT 资源时可以达到 50MBps，是因为 IPv6 校园网专用线路。也正是这样的高速专用 IPv6/IPv4 链路，孕育出多个高校 PT 站点。在这里，大家还保持着早期互联网的共享精神，相互分享、下载、传播互联网资源。

那么问题来了，毕业后的我们，如何翻越校园网防火墙，搭上专用 IPv6 高速链路，再体验一次学生时代呢？

## 内网穿透
[wiki-NAT穿越](https://www.wikiwand.com/zh-hans/NAT%E7%A9%BF%E9%80%8F)
内网穿透/NAT穿越（NAT traversal），涉及TCP/IP网络中的一个常见问题，即在处于使用了NAT设备的私有TCP/IP网络中的主机之间建立连接的问题。
尽管有许多穿越 NAT 的技术，但没有一项是完美的，这是因为 NAT 的行为是非标准化的。这些技术中的大多数都要求有一个公共服务器，而且这个服务器使用的是一个众所周知的、从全球任何地方都能访问得到的IP地址。一些方法仅在建立连接时需要使用这个服务器，而其它的方法则通过这个服务器中继所有的数据——这就引入了带宽开销的问题。
两种常用的NAT穿越技术是：UDP路由验证和STUN。除此之外，还有TURN、ICE、ALG，以及SBC。

一般内网穿透有以下几种方法：
1. 端口映射（Port Forwarding），将内网主机通过防火墙转发出来，映射到外层的某端口。（需要防火墙管理权限）
2. VPN链路，开启专用通道；
3. 反向链接（Reverse Connection），内网主机主动连接外网主机；

### autossh
上面提到过，校园网防火墙一般会拒绝外网的单向主动请求，除非内网有机器建立了相应链路。因此，我们需要一个“内应”，即一台处于校园网的机器及其登录权限。而且第一次需要有人主动操作内网服务器来建立请求。

autossh 是一个用来启动 SSH 并进行监控的程序，通过 autossh，内网机器通过防火墙利用 SSH 隧道搭建一个反向代理，建立端口映射关系，外网就可以主动访问内网的特定端口了。实际上 SSH 本身就可以搭建反向代理，但是由于网络故障或抖动，SSH 可能会断开，而 autossh 支持断开重连机制，确保 SSH 会话的稳定。

![ssh反向代理](https://image.seanxp.com/school-proxy/2.jpg)

[autossh (1) - Linux Man Pages](https://www.systutorials.com/docs/linux/man/1-autossh/)
autossh: monitor and restart ssh sessions
autossh is a program to start a copy of ssh and monitor it, restarting it as necessary should it die or stop passing traffic.

#### 1. 安装 autossh

    # yum install autossh
    # apt install autossh
    # pacman -S autossh
    # brew install autossh
    # pkg install autossh

#### 2. 启动 autossh
autossh 的使用也非常简单，一行命令即可：

    # autossh -M 45678 -fNR 40022:localhost:22 user@vps -p22

* -M port[:echo_port]，-M 45678：通过 45678 端口监视连接状态，连接有问题时就会自动重连 SSH；
* -N：不允许执行远程命令，只做端口转发。Do not execute a remote command. This is useful for just forwarding ports (protocol version 2 only).
* -R 40022:localhost:22 ：将内网主机的 22 端口和外网机器的 40022 端口绑定，相当于远程端口映射；访问外网 40022 端口就会被转发到内网的 22 端口；
* -p22，指定外网（user@vps）的 sshd 端口，autossh 就通过 SSH 通道建立的会话连接，因此内网机器必须可以通过 SSH 登录外网机器。
* -f，background，指定 autossh 在后台运行；

检查外网机器的端口是否正常启动：

    vps# netstat -antp | grep 40022

通过外网端口 40022 访问内网 22 端口，实现 SSH 登录内网机器：

    client# telnet vps 40022
    client# ssh user@vps -p40022

依赖条件：
1. 外网机器 VPS 防火墙开启 SSH 端口（22）及映射端口（40022），否则内网机器 autossh 无法正常搭建代理，客户端也无法连接外网机器；
2. 内网机器可以通过 SSH 连接外网机器（这里为了方便连接，一般可使用 SSH 公钥认证登录（ssh public key authentication）来避免手动输入密码；

### ngrok
![ngrok内网穿透](https://image.seanxp.com/school-proxy/3.png)

#### 简介
* [ngrok - Introspected tunnels to localhost](https://github.com/inconshreveable/ngrok)
* [使用Ngrok实现内网穿透](http://cjting.me/misc/ngrok-tutorial/)
* [搭建 ngrok 服务实现内网穿透](https://imququ.com/post/self-hosted-ngrokd.html)
* [「翻译」ngrok 1.X 配置文档](https://imlonghao.com/28.html)
* [使用ngrok+shadowsocks穿透内网校外也能畅快看论文](https://xingtingyang.com/866.html)
* [ngrok搭建指南](https://luozm.github.io/ngrok)

ngrok 是一款用 go 语言开发的开源软件，它是一个反向代理，通过在公共的端点（Public IP & Port）和本地运行的 Web 服务或 TCP 服务之间建立一个安全的通道，使得外网可以访问本地的计算机服务。

ngrok的主要用途有以下几种：

* 内网穿透，可代替vpn
* 将无外网IP的 desktop 映射到公网
* 临时搭建网络并分配二级域名
* 微信二次开发的本地调试

备注：ngrok 1.x 是开源的（https://github.com/inconshreveable/ngrok） ，ngrok官网目前是 2.x 版本，不开源，二者功能和命令有一些区别。

#### 配置流程

1. 环境配置，编程 ngrok 相关依赖工具（build-essential golang mercurial git）
2. git clone https://github.com/inconshreveable/ngrok
3. 生成证书，替换配置域名
4. 编译生成服务器版本 server 上安装的 ngrokd
5. 生成各个平台上的 client 上安装的 ngrok
6. 服务器端与客户端分别启动 ngrokd/ngrok，调试验证

注意：
* 防火墙设置：服务器和客户端都要关闭对应端口的防火墙，否则不能链接会一直显示 connecting 。
* 证书一定要设置正确：证书会被编译到可执行文件中去，所以设置的时候需要正确设置地址，如果设置错误，最好是重新 git clone 一份代码来配置，make clean 在这里面似乎不能清除原有的配置。
* 交叉编译的时候要注意平台是 32 位系统（386）、64 位系统（amd64）或者 arm，设置错了不能运行。

#### 证书生成
* [生成ngrok使用的自签加密证书](http://nullget.sourceforge.net/?q=node/873&lang=zh-hans)


    #!/bin/sh
    domain="yourdomain.com"

    openssl genrsa -out rootCA.key 2048
    openssl req -x509 -new -nodes -key rootCA.key -subj "/CN=$domain" -days 5000 -out rootCA.pem
    openssl genrsa -out device.key 2048
    openssl req -new -key device.key -subj "/CN=$domain" -out device.csr
    openssl x509 -req -in device.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out device.crt -days 5000

    cp rootCA.pem assets/client/tls/ngrokroot.crt
    cp device.crt assets/server/tls/snakeoil.crt
    cp device.key assets/server/tls/snakeoil.key

这里看到，一共有3个证书文件：

* rootCA.pem，自签根证书；
* snakeoil.crt，公钥证书文件；  
* snakeoil.key，私钥证书文件。

#### ngrok 配置文件

    server_addr: "ngrok.example.com:8080"
    trust_host_root_certs: false

    tunnels:
        sftp:
            remote_port: 50022
            proto:
                  tcp: 10022
        transmission:
            proto:
                  https: 9091
        ss:
        remote_port: 12345
            proto:
                  tcp: 12345

注意 HTTP 和 HTTPS 隧道可设置 subdomain 和 auth，而 TCP 里只能设置 remote_port。

### frp
* [github-frp](https://github.com/fatedier/frp)
* [frp中文文档](https://github.com/fatedier/frp/blob/master/README_zh.md)

![frp架构](https://image.seanxp.com/school-proxy/4.jpg)

根据对应的操作系统及架构，从 [Release](https://github.com/fatedier/frp/releases) 页面下载最新版本的程序。

    $ wget https://github.com/fatedier/frp/releases/download/v0.21.0/frp_0.21.0_linux_amd64.tar.gz

将 frps 及 frps.ini 放到具有公网 IP 的机器上。将 frpc 及 frpc.ini 放到处于内网环境的机器上。

官方已经提供了一个`frps_full.ini`和`frpc_full.ini`配置文件，里面有非常详细的配置。相比 autossh/ngrok，frp 的功能同样强大，而且配置简单。

简单启动：

    server# cd frp && ./frps -c frps.ini
    client # cd frp && ./frpc -c frpc.ini

调试完成以后，可以添加后台启动和开机启动。

## 校园网 IPv6
很多高校的校园网都覆盖有 IPv6，但是有时由于最后一层交换器配置问题等原因，可能导致服务器没有主动分配到 IPv6 地址。此时可以通过验证网络并手动配置的方式，手动配置校园网 IPv6 地址和 IPv6 网关。

如果可以 ping6 通校园网 IPv6 站点或其他 IPv6 站点，就无需再多配置了。（高校校园网是目前应用 IPv6 最普及的地方了，珍惜这样的网络环境，多了解一些未来的东西）

    # ping6 google.com
    # ping6 bt.neu6.edu.cn     # 六维空间 bt.neu6.edu.cn (2001:da8:9000::232)
    # ping6 bt.byr.cn         # 北邮人 bt.byr.cn (2001:da8:215:4078:250:56ff:fe97:654d)

### CERNET2
* [CERNET2](https://baike.baidu.com/item/CERNET2/1067345)
* [cernet2最大的IPV6网络](https://www.chenyudong.com/archives/cernet2-the-largest-cngi-ipv6-network.html)

第二代中国教育和科研计算机网 CERNET2（The China Education and Research Network 2）是中国下一代互联网示范工程CNGI最大的核心网和唯一的全国性学术网，是目前所知世界上规模最大的采用纯IPv6技术的下一代互联网主干网。

CERNET2主干网将充分使用CERNET的全国高速传输网，以 2.5Gbps-10Gbps 传输速率连接全国 20 个主要城市的 CERNET2 核心节点，实现全国 200 余所高校下一代互联网IPv6的高速接入，同时为全国其他科研院所和研发机构提供下一代互联网 IPv6 高速接入服务，并通过中国下一代互联网交换中心 CNGI-6IX，高速连接国内外下一代互联网。CERNET2主干网采用纯IPv6协议，为基于IPv6的下一代互联网技术提供了广阔的试验环境。

中国教育和科研计算机网CERNET始建于1994年，是中国第一个采用IPv6技术的全国性互联网，对中国互联网发展具有重大示范意义。
2001年，CERNET提出建设全国性下一代互联网CERNET2计划。2003年8月，CERNET2计划被纳入由国家发改委等八部委联合领导的中国下一代互联网示范工程CNGI。

![CERNET2的100所高校的主干网络拓扑图](https://image.seanxp.com/school-proxy/5.jpg)

### [IPv6](https://www.wikiwand.com/zh-hans/IPv6)
网际网路通讯协定第6版（英文：Internet Protocol version 6，缩写：IPv6）是互联网协议的最新版本，用于封包交换互联网络的网路层协议，旨在解决IPv4地址枯竭问题。

IPv6的计划是建立未来网际网路扩充的基础，其目标是取代IPv4。虽然IPv6在1994年就已被IETF指定作为IPv4的下一代标准，由于早期的路由器、防火墙、企业的企业资源计划系统及相关应用程式皆须改写，所以在世界范围内使用IPv6部署的公众网与IPv4相比还非常的少，技术上仍以双架构并存居多。

在Internet上，数据以分组的形式传输。**IPv6定义了一种新的分组格式，目的是为了最小化路由器处理的报文首部。**由于IPv4报文和IPv6报文首部有很大不同，因此这两种协议无法互操作。但是在大多数情况下，IPv6仅仅是对IPv4的一种保守扩展。

* 当连接到IPv6网络上时，IPv6主机可以使用邻居发现协议对自身进行自动配置。当第一次连接到网络上时，主机发送一个链路本地路由器请求（solicitation）多播请求来获取配置参数。路由器使用包含Internet层配置参数的路由器宣告（advertisement）报文进行回应。
* 在不适合使用IPv6无状态地址自动配置的场景下，网络可以使用有状态配置，如DHCPv6，或者使用静态方法手动配置。

#### 地址格式
IPv6具有比IPv4大得多的编码地址空间。这是因为IPv6采用了128位元的地址，而IPv4使用的是32位元。

IPv6二进位制下为128位元长度，以16位元为一组（4个十六进制数字，每个对应 4 bit），每组以冒号“:”隔开，可以分为8组，每组以4位十六进制方式表示。

例如：2001:0db8:85a3:08d3:1319:8a2e:0370:7344 是一个合法的IPv6位址。

每项数字前导的0可以省略，省略后前导数字仍是0则继续，例如下组IPv6是相等的。

2001:0DB8:02de:0000:0000:0000:0000:0e13
2001:DB8:2de:0000:0000:0000:0000:e13
2001:DB8:2de:000:000:000:000:e13
2001:DB8:2de:00:00:00:00:e13
2001:DB8:2de:0:0:0:0:e13
2001:DB8:2de::e13

**可以用双冒号“::”表示一组0或多组连续的0，但只能出现一次。**
如果四组数字都是零，可以被省略。遵照以上省略规则，下面这两组IPv6都是相等的。
2001:DB8:2de:0:0:0:0:e13
2001:DB8:2de::e13

2001::25de::cade 是非法的，因为双冒号出现了两次。它有可能是下种情形之一，造成无法推断。
2001:0000:0000:0000:0000:25de:0000:cade
2001:0000:0000:0000:25de:0000:0000:cade
2001:0000:0000:25de:0000:0000:0000:cade
2001:0000:25de:0000:0000:0000:0000:cade

如果这个位址实际上是IPv4的位址，后32位元可以用10进制数表示；因此 ::ffff:192.168.89.9 相等于 ::ffff:c0a8:5909 ，但不等于::192.168.89.9 和::c0a8:5909。
另外，::ffff:1.2.3.4 格式叫做IPv4映射位址。而::1.2.3.4 格式叫做IPv4一致位址，目前已被取消。

IPv4位址可以很容易的转化为IPv6格式。举例来说，如果IPv4的一个位址为135.75.43.52（十六进位为0x874B2B34），它可以被转化为0000:0000:0000:0000:0000:ffff:874B:2B34 或者::ffff:874B:2B34。同时，还可以使用混合符号（IPv4-compatible address），则位址可以为::ffff:135.75.43.52。

类似于IPv4中的CDIR表示法，IPv6用前缀来表示网络地址空间，比如： 
2001:250:6000::/48 表示前缀为48位的地址空间（一个子段是16位，共有8个子段），其后的80位可分配给网络中的主机，共有2的80次方个地址 

#### IPv6位址的分类
IPv6位址可分为三种：
* 单播（unicast）位址，单播位址标示一个网路介面。协议会把送往位址的封包投送给其介面。单播地址包括可聚类的全球单播地址、链路本地地址等。  
* 任播（anycast）位址，Anycast是IPv6特有的资料传送方式，它像是IPv4的Unicast（单点传播）与Broadcast（多点广播）的综合。以目前的应用为例，Anycast位址只能分配给路由器，不能分配给电脑使用，而且不能作为发送端的位址。  
* 多播（multicast）位址，多播地址也称组播地址。多播位址也被指定到一群不同的介面，送到多播位址的封包会被传送到所有的位址。多播位址由皆为一的位元组起始，亦即：它们的前置为FF00::/8。其第二个位元组的最后四个位元用以标明"范畴"。  

特殊位址，IPv6中有些位址是有特殊含义的：
* 未指定位址，::/128－所有位元皆为零的位址称作未指定位址(即0:0:0:0:0:0:0:0)。只能作为尚未获得正式地址的主机的源地址，不能作为目的地址，不能分配给真实的网络接口 这个位址不可指定给某个网路介面，并且只有在主机尚未知道其来源IP时，才会用于软体中。路由器不可转送包含未指定位址的封包。  
* 链路本地位址，::1/128－是一种单播绕回位址(0:0:0:0:0:0:0:1, 回环地址，相当于ipv4中的localhost（127.0.0.1），ping locahost可得到此地址)。如果一个应用程式将封包送到此位址，IPv6堆叠会转送这些封包绕回到同样的虚拟介面（相当于IPv4中的127.0.0.1/8）。fe80::/10－这些链路本地位址指明，这些位址只在区域连线中是合法的，这有点类似于IPv4中的169.254.0.0/16。  
* 唯一区域位域,fc00::/7－唯一区域位址（ULA，unique local address）只可在一群网站中。  

#### ping6
类似 ping 127.0.0.1 一样，ping 本地网络环路 lo：

    $ ping6 ::1

向多播地址 ff02::1 发送PING可以获得局域网内所有主机的回应。使用时需要注明网卡：
Pinging the multicast address ff02::1 results in all hosts in link-local scope responding. An interface has to be specified:

    $ ping6 ff02::1%eth0

**FF02::1 指所有开启了IPv6组播的主机，和IGMP中的224.0.0.1对应。**

macOS 下不指定主机，会提示出错：`（ping6: UDP connect: No route to host）`，使用 -I 选项或 %选项 指定走哪个网络接口。
Linux 下不指定主机，会提示出错：`（connect: Invalid argument）`。

http://natesilva.tumblr.com/post/2502342060/using-ping6-on-mac-os-x-or-linux
The solution is to pass the -I command-line argument. Give it the name of the interface you want to ping from. For example, the first ethernet port on Linux is usually called eth0. On a Mac, it’s usually en0 or en1.
$ ping6 -I eth0 ff02::1
$ ping6 ff02::1%eth0

macOS 下进行 ping6 获取局域网内所有主机回应：
$ ping6 ff02::1%en0
PING6(56=40+8+8 bytes) fe80::1443:26e5:ff70:5d8e%en0 --> ff02::1%en0
16 bytes from fe80::1443:26e5:ff70:5d8e%en0, icmp_seq=0 hlim=64 time=0.149 ms
16 bytes from fe80::5e63:bfff:fed8:cc2a%en0, icmp_seq=0 hlim=64 time=1.945 ms

* fe80::1443:26e5:ff70:5d8e%en0 --> ff02::1%en0，说明是从本机接口 en0 的 fe80::1443:26e5:ff70:5d8e 向组播地址 ff02::1 发送 ICMP 包；  
* 16 bytes from fe80::1443:26e5:ff70:5d8e%en0，表明本机接口 en0 的 IPv6 地址首先回应了组播包，由于是本机回复本机，因此时间很短，time=0.149 ms；  
* 16 bytes from fe80::5e63:bfff:fed8:cc2a%en0，是另一台开启 IPv6 组播的主机对本机接口 en0 的回复，和上一个的延时相比长了很多，time=1.945 ms；经过调查发现，此 IPv6 地址，是本机上游路由器的 eth0 接口（也是本机的 IPv4 上游接口）的地址：inet6 fe80::5e63:bfff:fed8:cc2a/64 scope link；  

### IPv6 配置

1. 熟悉所在学校的校园网的常用 IPv6 地址（一般校园 PT 论坛可以搜索到，或者询问网络中心管理员）。
例如某高校使用的 IPv6 网段为：`2001:250:fe01:123::/64`，前四个子段为网络号，后面四个子段为主机号，由于 IPv6 主机号地址非常多，这里可以随意配置，只要和他人不冲突即可。一般校园网可能会以 IPv4 地址作为后面四个子段的主机号配置。

2. 手动配置 IPv6 address & IPv6 gateway；

        $ ip -6 addr add 2001:250:fe01:123:a192:a168:a001:a001/64 dev enp1s0
        $ ip -6 addr add fe80::a192:a168:a001:a001/64 dev enp1s0 # fe80:: 组播地址，实际上不影响 bt 下载
        $ ip -6 route add default via 2001:250:fe01:123::1 dev enp1s0

3. 验证配置是否生效。

        $ ping6 2001:250:fe01:123::1 # 到网关
        $ ping6 bt.neu6.edu.cn # 到bt站点
        $ mtr bt.neu6.edu.cn

## 校园网代理

内网穿透是为了反向代理映射校园网端口到公网服务器，**穿透的目的之一就是使用校园网来访问互联网资源，尤其是一些高校资源（知网、IPv6 PT 站点等）。** 因此需要在校园网内网机器上搭建 ss server 端，配置监听端口，并通过 autossh/ngrok/frp 反向代理该监听端口，一般可以映射到公网服务器 VPS 的 443 端口。

ss 代理教程网络上非常多，本博客也有[一篇](https://seanxp.com/2016/05/shadowsocks/)，还有简单的[一键部署脚本](https://teddysun.com/)，这里不再赘述。

搭建代理后，甚至可以在手机端通过校园网访问知网（具有校园网 IP 的权限），或者浏览 IPv6 站点。

除了网络代理，还可以通过反向代理 ssh 实现登录内网机器，代理 ftp 实现下载校园网资源等等。

