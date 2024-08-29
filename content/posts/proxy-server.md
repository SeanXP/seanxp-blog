---
title: 网络代理服务器
date: 2018-08-12T10:38:27+08:00
tags:
  - 计算机网络
  - 网络代理
  - 工具
categories:
  - 网络技术
draft: false
featuredImage: https://image.seanxp.com/proxy-server/0.jpg
---
剑阁峥嵘而崔嵬，一夫当关，万夫莫开。
<!--more-->

* [wiki-代理服务器](https://www.wikiwand.com/zh/%E4%BB%A3%E7%90%86%E6%9C%8D%E5%8A%A1%E5%99%A8)
* [proxy flow chart](https://docs.mitmproxy.org/stable/concepts-modes/)

<!--![代理选择](https://ws4.sinaimg.cn/large/0069RVTdgy1fu6rqoy6qtj312o0sgwg5.jpg)-->
![代理选择](https://image.seanxp.com/proxy-server/1.jpg)

## 正向代理（Forward Proxy）
正向代理/客户端代理，**隐藏了真实的请求客户端**，服务端不知道真实的客户端是谁，客户端请求的服务都被代理服务器代替来请求。
**正向代理用于获取互联网资源**，作为一个媒介，将互联网上获取的资源返回给相关联的客户端。某科学的超（fan）电（qiang）磁（gong）炮（ju）扮演的就是典型的正向代理角色。

<!--![正向代理示意图](https://ws2.sinaimg.cn/large/0069RVTdgy1fu6qazmkmhj30zk0dcwg2.jpg)-->
![正向代理示意图](https://image.seanxp.com/proxy-server/2.jpg)

根据代理服务器的部署位置，可分为以下两种用法：
1. 正向代理服务器处于防火墙内，正义的防火墙可以保护局域网，只留正向代理服务器一个入口为局域网内的客户端提供访问 nternet 的途径，且对外屏蔽客户端的细节。正向代理还可以使用缓冲特性减少网络使用率。
2. 正向代理服务器处于防火墙外，“正义”的防火墙可以阻止客户端“不合理”的请求，只留下发往正向代理服务器的“合理”请求。客户端和代理端往往通过加密混淆等方式，将“不合理”化为“合理”的请求。

正向代理的主要作用为：
* 作为跳板机，从另一条路由路径访问本无法直接访问的服务器；
* 加速访问资源；（历史遗留，低带宽链路通过代理的高带宽链路加速访问）
* 缓存，加速访问；（加速同一网络下的重复资源请求）
* 对客户端访问授权，上网进行认证；未经过授权（没有配置代理）的客户端请求将被丢弃；
* 代理可以记录用户访问记录（上网行为管理），对外隐藏用户信息；

## 反向代理（Reverse Proxy）
* [Wiki - 反向代理](https://www.wikiwand.com/zh-hans/%E5%8F%8D%E5%90%91%E4%BB%A3%E7%90%86)
* [反向代理为何叫反向代理？](https://www.zhihu.com/question/24723688)

反向代理/服务端代理，**隐藏了真实的响应服务端**，客户端不知道真是的服务器是谁，客户端发出的请求都被反向代理服务器来代替请求。
**反向代理用于提供互联网资源**，作为一个媒介，将后端的服务器资源返回给互联网上相关联的客户端。很多互联网提供商（BAT）都有对应的反向代理。

<!--![反向代理示意图](https://ws2.sinaimg.cn/large/0069RVTdgy1fu6qyf7scxj30xc0cijss.jpg)-->
![反向代理示意图](https://image.seanxp.com/proxy-server/3.jpg)

反向代理的典型用途是将防火墙后面的服务器提供给 Internet 用户访问，并提供服务器端的安全防护。反向代理还可以为后端的多台服务器提供负载平衡，或为后端较慢的服务器提供缓冲服务。Nginx 就是性能非常好的反向代理服务器，用来做负载均衡。

反向代理的主要作用为：
* 保护和隐藏原始资源服务器
* 加密和SSL加速
* 负载均衡
* 缓存静态内容，减少服务器的访问压力。
* 压缩
* 减速上传
* 安全
* 外网发布

## 透明代理（Transparent Proxy）

这个其实不能和正向、反向代理并列，因为**透明代理是正向代理中的一种**。透明代理的意思是**客户端根本不需要知道有代理服务器的存在**，它改变你的 request fields（报文），并会传送真实 IP，多用于路由器的 NAT 转发中。注意，加密的透明代理则是属于匿名代理，意思是不用设置使用代理了。
**透明代理不但改动了数据包，还会告诉服务器客户端的真实IP**。它不会加密你的信息，而是明明白白的告诉目标站你是通过代理访问的。当然好处是可以通过缓存技术提高浏览速度，以及一些规则来让你的访问变得更加安全（典型应用就是内网硬件防火墙上的透明代理）。（不过，我们常说的 ss 透明代理与此定义不同，前者表示相对电脑访问，代理是透明的；后者表示相对目标站点，代理是透明的。）

而在国内，透明代理有了其他一些用途：
* [ss-redir 透明代理](https://www.zfl9.com/ss-redir.html)
* [如何在路由器中实现透明代理？](https://gist.github.com/snakevil/8a34d6fbdf2a64f2c753)
* 公司行为管理透明代理软件，客户端感知不到代理服务器的存在，透明代理设备根据自身策略拦截并修改报文，最后回传信息。但是发出的部分网络请求将会被拒绝掉。

## 拦截代理（Intercepting Proxy）
* [使用 mitmproxy + python 做拦截代理](https://blog.wolfogre.com/posts/usage-of-mitmproxy/)
* [mitmproxy](https://mitmproxy.org/)

拦截代理，用于拦截所有通过代理的网络流量，如客户端的请求数据、服务器端的返回信息等。常用于网络服务开发者的测试或安全评估。客户端主动通过代理访问并进行拦截处理，是为拦截代理；若客户端不知道是通过代理访问且被拦截请求，是为中间人攻击（MITM）。

拦截代理软件：
* [Charles(Mac)](https://www.charlesproxy.com/)
* [Fiddler(Windows)](https://www.telerik.com/fiddler)
* [mitmproxy(HTTPS proxy)](https://mitmproxy.org/)

<!--![手机https拦截代理](https://ws1.sinaimg.cn/large/0069RVTdgy1fu6sm9q0u3j30hq0dbgm7.jpg)-->
![手机https拦截代理](https://image.seanxp.com/proxy-server/4.jpg)

mitmproxy 是用 Python 和 C 开发的一个中间人代理软件（man-in-the-middle proxy），它可以用来拦截、修改、重放和保存 HTTP/HTTPS 请求。mitmproxy 就是用于 MITM 的 proxy。用于中间人攻击的代理首先会向正常的代理一样转发请求，保障服务端与客户端的通信，其次，会适时的查、记录其截获的数据，或篡改数据，引发服务端或客户端特定的行为。不同于 fiddler 或 wireshark 等抓包工具，mitmproxy 不仅可以截获请求帮助开发者查看、分析，更可以通过自定义脚本进行二次开发。

但 mitmproxy 并不会真的对无辜的人发起中间人攻击，由于 mitmproxy 工作在 HTTP 层，而当前 HTTPS 的普及让客户端拥有了检测并规避中间人攻击的能力，所以**要让 mitmproxy 能够正常工作，必须要让客户端（APP 或浏览器）主动信任 mitmproxy 的 SSL 证书，或忽略证书异常**，这也就意味着 APP 或浏览器是属于开发者本人的——显而易见，这不是在做黑产，而是在做开发或测试。


