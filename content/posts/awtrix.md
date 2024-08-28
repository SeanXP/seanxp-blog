---
title: DIY Awtrix WiFi Clock
date: 2019-05-12T06:28:09+08:00
tags:
  - 嵌入式
  - 生活
  - DIY
categories:
  - 科技数码
draft: false
---

<div align=center>
<img src="https://seanxpcom-1252122045.cos.ap-nanjing.myqcloud.com/awtrix/0.jpg" alt='shut up and take my money'/>
<blockquote class="blockquote-center">小明在用 $200 买来的 Lametric Time，我在用 ￥200 DIY 的 AWTRIX Clock：
	我们都有着光明的未来。
</blockquote>
</div>
<!--more-->
![Awtrix-SeanXP](https://seanxpcom-1252122045.cos.ap-nanjing.myqcloud.com/awtrix/1.jpg)
![Awtrix-matrix](https://seanxpcom-1252122045.cos.ap-nanjing.myqcloud.com/awtrix/2.jpg)

## 相关材料
1. WS2812B 8x32 全彩可编程像素软屏（淘宝115元）
2. ESP8266 WIFI 模块 CP2102 ESP-12E （淘宝27.83元）
3. 杜邦线，公对母，一排即可，连接 ESP8266 模块与WS2812B 的 DIN侧端口（淘宝3.58元）
4. [Smart RGB Matrix 3D](https://www.thingiverse.com/thing:2791276)
	* LEDGrid2x.stl（8 x 16），光栅（光栅的作用是让圆的光点变成四方的像素，看起来更大更舒服），必选打印，材料黑色不透光，需打印2份拼装成 8 x 32；（70元透光材料效果不佳，170元不透光材料效果佳）
	* frontFrame2x.stl（8 x 16），前壳，可选打印，需打印2份拼装成 8 x 32；（50.10 元）
	* Housing.stl，后壳，可选打印；
5. A3 打印白纸一张（A4 纸长度不够）
6. micro usb 线（连接 WIFI 模块）
7. 一台 Linux Server，需安装 Awtrix Server
8. 502胶水、美工刀等工具

![3d打印](https://seanxpcom-1252122045.cos.ap-nanjing.myqcloud.com/awtrix/3.png)
实际成本：硬件部分（115+27.83+3.58），3D打印部分（246.04元），成本在400元左右。

## DIY流程
网络教程一致，都基于官方文档，不再赘述，参考：
* [如何制作一个 WIFI 像素时钟](https://pengchujin.github.io/post/a46d7696.html)
* [DIY媲美LaMetric的可编程电子钟](https://www.bilibili.com/video/av49768953)
* [blueforcer](https://docs.blueforcer.de/#/v2/README)

1. 3D 打印精度较差，需要 502 胶水拼装，无法粘合可进一步使用胶枪（淘宝10元）；
2. 公对母杜邦线连接 WS2812B、ESP8266，可进一步使用电烙铁直接焊接端口固定；
3. 线路连接验证后，可使用黑色绝缘胶带或胶枪包裹像素屏背后的各个焊点，避免意外短路；
4. 可多预备几张 A3 打印纸，前端可考虑包裹一层塑料纸，防脏防水；
5. 后端可连接充电宝，脱离电源插座的束缚；
6. [502胶水沾到手上如何处理？](https://www.zhihu.com/question/20045402/answer/16456670)，使用肥皂洗手；
7. 如果使用 VPS 搭建 Awtrix Server，需开通网络端口 7000/7001，建议修改端口再烧写到客户端；

## 远程控制
* [api](https://docs.blueforcer.de/#/v2/api)
* [Telegram-Bot](https://www.bilibili.com/video/av51122911)

示例：
```
curl --header "Content-Type: application/json" --request POST --data {"msgEndless":"Hello World"} http://[AWTRIX-SERVER_IP]:7000/api/v3/basics
```