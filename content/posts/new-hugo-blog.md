---
title: 我的 Hugo 新博客：反思与搭建
categories:
  - 生活随笔
tags:
  - DIY
  - Blog
date: 2024-08-27T08:08:26+08:00
draft: false
feature:
---
凡是过去，皆为序章 (What's past is prologue)
<!--more-->
## 反思

快两年没有写博客了，反思一下：
* 一是“乱花渐欲迷人眼”，有趣好玩的东西太多，游戏、电影、动漫等，**周末时间根本不够用**。
* 二是**写博客耗费的时间精力太多了**，一篇十分钟的文章，写起来可能就要花一个周末，主题构思、素材整理、内容删减、图库调整、博客调试，最终输出，"Boom..."，已经到周日深夜了。加上之前使用 hexo + Github Pages 来搭建博客，hexo 很久没更新，就完全编译不通过；Github pages 在国内访问也很慢，又熄灭了想要写博客的冲动。

然后，最近的思维开始转变：
* 有趣的事情确实很多，但是还是需要保留一定的时间去“输出”。学到了新东西，结合费曼学习法，用自己的话总结下；玩到了新游戏，发篇博客分享下。**“输出”是为了完善自己的信息流，形成一个完整的闭环，也能顺便锻炼下自己的文字、思维能力**。
	* [The Surprising Reason Writing Remains Essential in an AI-Driven World](https://fs.blog/why-write/)
	* Writing is the process by which you figure it out. Writing about something is one of the best ways to learn about it.
* 作为一名 IT 从业者，总是想不起来自动化，实在惭愧。写博客这件事是好的，道路也是曲折的，那就利用 IT 技术去**尽可能的自动化，减少阻力**。
* **博客是写给自己的，顺便给他人看的**。之前导向错了，所以很多值得总结的内容，都写在了个人笔记系统里面，并没有分享出来。但是从我个人使用互联网的经验，自己的个人笔记再全面，也不过是互联网内容中的沧海一粟。不如把自己的笔记共享出来，一起共建一个更好的互联网。

## 原则

1. 自动化: 确保 99% 的时间精力都用在内容上，而非配置、解决博客系统构建等问题上；
2. 简单化: 博客系统简单点，不需要各种花里胡哨的插件。文章的配图、序言能省就省，直入主题最重要；
3. 日常化: 日常学习到的值得分享的内容，简单整理下就分享处理，不用“攒大招”搞一个系列出来；就当作是个人的公开笔记（“笔记”而非“博客”）

### 分类方式
分类（category）为主，标签（tag）为辅。一篇文章只能属于一个「分类」，但能拥有多个「tag」。

使用 Claude 针对我以前的博客分类/标签进行了归纳总结，整理出下面的分类，感觉还不错，试用一段时间看看：
- 读书笔记
- 影视笔记
- 旅游游记
- 金融理财
- 科技数码
- 历史文化
- 游戏体验
- 生活随笔
- 网络技术

参考：
* [如何规划blog的标签（tag）和分类 - 心内求法 - 博客园](https://www.cnblogs.com/holbrook/archive/2012/11/05/2755268.html)
* [个人博客的分类划分](https://noodlefighter.com/posts/2836/)

## 博客方案
我的博客系统由以下几个主要组件构成：
- 域名： `seanxp.com`
	- 托管于 `Cloudfare`，使用 `Cloudfare Pages` 服务；
	- 选择原因: `Cloudflare` 提供免费的 CDN 加速,有助于提高全球访问速度；
- 博客系统： `Hugo` + `DoIt` 主题
	- [Hugo](https://gohugo.io/)：高效的静态网站生成器，不会像 `hexo` 那样许久未更新就报一堆 js 错误，无依赖性，golang 语言（golang 粉丝狂喜）；
	- [DoIt](https://github.com/HEIGE-PCloud/DoIt) 主题: 功能丰富的 Hugo 主题，支持国际化、评论系统、图库、搜索、统计、加密、PWA 等；
- 自动化构建: `Cloudflare Pages` 关联 GitHub，自动构建静态页面
	- 工作流程：
	  1. 在本地编写文章并提交到 GitHub 仓库
	  2. Cloudflare Pages 自动检测到 GitHub 仓库更新
	  3. 触发自动构建和部署流程
	- 优势: 
		- 无需手动部署,节省时间
		- 确保线上内容始终与 GitHub 仓库同步
		- 构建速度是真的快，推送后 20s 内就可以完成构建
- 内容管理：`obsidian` + `obsidian-git` + `Templater`
	- 本地使用 `obsidian` 编辑器（个人笔记系统），单独拆分 vault 保存博客文章；
	- 使用 Markdown 格式编写文章，利用 `Templater` 插件，指定文件夹模板，可在新文件中快速新增 hugo 元数据；
	- 利用 Git 进行版本控制，使用 `obsidian-git` 插件，方便快速更新博客文章，推送 github。
	- [obsidian 配合 hugo、cloudflare：让发布博客简单到不可思议 :: Lillian Who](https://lillianwho.com/posts/obsidian-hugo-cloudflare/)
	- [Hugo With Obsidian :: 木木木木木](https://immmmm.com/hugo-with-obsidian/)
- 评论系统: `Remark42` + `fly.io`
	- Go 语言实现，支持多种方式登录（包括匿名登录）、可以直接在评论界面管理评论。
	- [从零开始搭建你的免费博客评论系统（Remark42 + fly.io） · Pseudoyu](https://www.pseudoyu.com/zh/2024/07/22/free_commenting_system_using_remark42_and_flyio/)
- 图片存储：`Cloudfare R2` + `WebP Cloud` + `PicGo` + `Image Auto Upload Plugin`
	- 使用 `Cloudfare R2` 作为图床，相比 `Github` 图床，`Cloudfare R2` 在国内访问速度更快；
	- 使用 `WebP Cloud` 管理图片，可以批量上传、删除图片，并生成图片链接，方便快捷，还可以缩小图片体积，减少带宽消耗。
	- 使用 `PicGo` 作为图床客户端，可以上传图片到 `Cloudfare R2`，并生成图片链接，支持自定义域名。
	- 使用 `Image Auto Upload Plugin` 插件，结合 PicGo 使用，可以自动上传图片，并生成图片链接。
	- [从零开始搭建你的免费图床系统（Cloudflare R2 + WebP Cloud + PicGo） · Pseudoyu](https://www.pseudoyu.com/zh/2024/06/30/free_image_hosting_system_using_r2_webp_cloud_and_picgo/)
	- [使用 WebP Cloud 与 Cloudflare WAF 为你的图床添加隐私和版权保护 · Pseudoyu](https://www.pseudoyu.com/zh/2024/07/02/protect_your_image_using_webp_and_cloudflare_waf/)
- 网站统计：`umani` + `Railway`
	- Railway 一键部署，只需要配好自定义域名，在 DoIt 模板填好 umami 参数即可。
- 全文搜索：`Algolia`
	- 使用 `Algolia` 作为全文搜索服务，支持中文搜索，搜索结果高亮显示，搜索体验非常好。