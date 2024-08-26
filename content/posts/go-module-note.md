---
title: Go Module Notes
date: 2019-05-29T10:46:49+08:00
tags: ["Learning", "Golang"]
categories: ["Notes"]
draft: false
---


<div align=center>
<blockquote class="blockquote-center">我的附庸的附庸，不是我的附庸；
我的 module 的 module，仍是我的 module！
</blockquote>
</div>

<!--more-->

Go 1.11 版本包含了两个最重要的 feature 就是 module 和 web assembly。Golang官方自go1.11版本初步引入，go1.12版本正式支持go Modules官方包依赖管理工具。

## 什么是 go module？

模块 ( module ) 是相关 go 包的集合，是源代码交换 ( interchange ) 和版本化控制（Version control）的基本单元。

* 「模块根目录」 ( Module root ) : 包含了名为 go.mod 文件的目录；
* 「模块路径」 ( Module path ) : 与模块根目录对应的导入路径的前缀；  
* 「主模块」( Main module ) : 包行了运行 go 命令的所在目录的模块；

module 和传统的 GOPATH 不同，不需要包含例如src，bin这样的子目录，一个源代码目录甚至是空目录都可以作为 module，只要其中包含有 go.mod 文件。当我们使用 go build，go test 以及 go list 时，go会自动得更新go.mod文件，将依赖关系写入其中。

module 是包含了 Go 源文件的目录树，并在根目录中添加了名为 go.mod 的文件。go.mod 包含模块导入名称，声明了要求的依赖项，排除的依赖项和替换的依赖项。go.mod 文件还定义了模块的 dependency requirements（依赖项要求），即为了编译本模块，需要用到哪些其它的模块。每一项依赖项要求都包含了依赖项的 module path，还要指定它的语义版本号。除了 go.mod 文件外，跟目录下还可以存在一个名为 go.sum 的文件，用于保存所有的依赖项的哈希摘要校验值，用于验证缓存的依赖项是否满足模块要求。

模块依赖项会被下载并存储到 `GOPATH/src/pkg/mod` 目录中，直接后果就是废除了模块的组织名称，文件结构如下：

![](https://seanxpcom-1252122045.cos.ap-nanjing.myqcloud.com/images/go-module-note-0.png)
* cache，包含每一个 module 的每一个缓存版本，从 VCS 中获取或构建的源归档文件放置在 download 目录中；
    * .info, 包含 Version & Time;
    * .zip, module src zip，解压后就是 go module 源码；
    * .ziphash, zip hash，也就是 go.sum 里面的 hash 值；
* github.com/me/lib@1.0.0，go module 源码集合，路径以 @version 为后缀，用于区分不同版本；

## go module init

	$ go mod init <ROOTPATH>

ROOTPATH 可以是标准的 module path，即一个外网可访问的地址，例如：github.com/BurntSushi/toml；ROOTPATH 也可以是一个简单的 Package Name，即表示这个 Module 不打算提供给他人，只是自己使用，例如：helloworld。

默认情况下，$GOPATH 里面是禁用 modules 支持的，需要在 $GOPATH 目录之外创建 mod 目录。
启用了 module 机制的包（库）或者可执行文件，它们的代码都必需放在非 GOPATH 的目录里面，这是必需条件，不是可选的条件。 如果对 GOPATH 目录里面的项目 执行 go mod init mod 那么将会报错：

	go: modules disabled inside GOPATH/src by GO111MODULE=auto; see 'go help modules’。

在 Go 1.11beta2 中，可以通过设置环境变量 GO111MODULE 控制是启用还是禁用模块支持。它接受三个值：on，off，auto ( 默认 )

* 如果设置为 on ，那么无论模块在于何种路径，都会启用模块支持
* 如果设置为 off，则永远禁用 go module 支持
* 如果没有设置，或设置为 auto，开启支持模块功能，但如果模块路径位于 GOPATH 路径之外，则需要当前目录是模块根目录或其子目录之一。

对于 Go 1.11 来说（GO111MODULE = auto），当你工作目录不在 $GOPATH/src 里面，并且工作目录或者工作目录的任意级父目录中含有 go.mod 文件，go 命令行工具会启用 go module 机制。
注意：一个不包含任意代码的目录也可以成为 go module，只要包含 go.mod 文件，就认为是一个 go module。

## go module import

在你的代码中 import 了一个包，但 go.mod 文件里面又没有指定这个包的时候，go 命令行工具会自动寻找包含这个代码包的模块的“最新”版本，并添加到 go.mod 中。
所谓的“最新”版本：

1. 最近一次被 tag 的稳定版本（即非预发布版本，non-prerelease）；
2. 如果第1项没有，则最近一次被 tag 的预发布版本；
3. 如果前2项没有，则最新的没有被 tag 过的版本；

go module 版本号遵循如下规律（版本号+时间戳+hash）：

* vX.Y.Z-pre.0.yyyymmddhhmmss-abcdefabcdef
* vX.0.0-yyyymmddhhmmss-abcdefabcdef
* vX.Y.(Z+1)-0.yyyymmddhhmmss-abcdefabcdef
* vX.Y.Z

## go module list

go list -m all 命令会把当前的模块和它所有的依赖项都列出来。

	$ go list -m all
查看一个 go module 的所有版本列表：

	$ go list -m -versions github.com/BurntSushi/toml

## go module update

默认情况下，Go 不会自己更新模块，这是一个好事因为我们希望我们的构建是有可预见性（predictability）的。

* 运行 **go get -u** 将会升级到最新的次要版本或者修订版本（比如说，将会从 1.0.0 版本，升级到——举个例子——1.0.1 版本，或者 1.1.0 版本，如果 1.1.0 版本存在的话）
* 运行 **go get -u=patch** 将会升级到最新的修订版本（比如说，将会升级到 1.0.1 版本，但不会升级到 1.1.0 版本）
* 运行 **go get package@version** 将会升级到指定的版本号

根据语义化版本的语义，主要版本与次要版本是不同的，主要版本可以打破向后兼容性。从 Go modules 的角度来说，一个包，如果两个主要版本号不同的话，那这它们相当于两个完全不同的包。

## Go module tidy 依赖项整理

默认情况下，Go 并不会在 go.mod 上面移除掉依赖项，除非你明确地指示它这么做。清除没用到的 module 依赖项：

	$ go mod tidy
这条命令会自动更新/整理依赖关系，并且将包下载放入 cache。

## 语义化的导入版本控制

golang 官方推荐的最佳实践叫做 semver，这是一个简称，写全了就是 Semantic Versioning（语义化版本）。通俗地说，就是一种清晰可读的，明确反应版本信息的版本格式。
通过semver对版本进行严格的约束，可以最大程度地保证向后兼容以及避免“breaking changes”，而这些都是golang所追求的。两者一拍即合，所以go modules提供了语义化版本的支持。如果你使用和发布的包没有版本tag或者处于1.x版本，那么你可能体会不到什么区别，因为go mod所支持的格式从始至终是遵循semver的，semver 主要的区别体现在v2.0.0以及更高版本的包上。

	“如果旧软件包和新软件包具有相同的导入路径，则新软件包必须向后兼容旧软件包。” - go modules wiki

不同主版本号的同一个 Go 模块，使用了不同的 module path ——从 v2 开始，module path 的结尾一定要跟上主要版本号。格式总结为 `pkgpath/vN`，其中N是大于1的主要版本号。在代码里导入时也需要附带上这个版本信息，如 import "some/pkg/v2"。如此一来包的导入路径发生了变化，也不用担心名称相同的对象需要向后兼容的限制了，因为golang认为不同的导入路径意味着不同的包。v2+版本的包允许和其他不同大版本的包同时存在（前提是添加了/vN），它们将被当做不同的包来处理。

不过这里有几个例外可以不用参照这种写法：
* 当使用gopkg.in格式时可以使用等价的require gopkg.in/some/pkg.v2 v2.0.0
* 在版本信息后加上+incompatible就可以不需要指定/vN，例如：require some/pkg v2.0.0+incompatible

## go module 使用本地包

本地开发的包，还没有远程仓库的时候，要怎么解决本地包依赖问题呢?

	require my/example/pkg v0.0.0
	replace my/example/pkg => ./pkg

至于pkg/go.mod，使用go mod init生成后不用做任何修改，它只是让我们的pkg成为一个module，因为replace的源和目标都只能是go modules。

因为被 replace 的包首先需要被 require，所以在my-mod/go.mod中我们需要先指定依赖的包，即使它并不存在。对于一个会被replace的包，如果是用本地的module进行替换，那么可以指定版本为v0.0.0(对于没有使用版本控制的包只能指定这个版本)，否则应该和替换包的指定版本一致。
同时，使用本地包进行替换时并不会生成go.sum所需的信息，所以go.sum文件也没有生成。

	go mod edit -replace=old[@v]=new[@v]

* replace应该在引入新的依赖后立即执行，以免go tools自动更新mod文件时使用了old package导致可能的失败；
* package后面的version不可省略。（edit所有操作都需要版本tag）
* version不能是master或者latest，这两者go get可用，但是go mod edit不可识别，会报错。

## 顶层依赖与间接依赖

如果你因为 golang.org/x/... 无法获取而使用replace进行替换，那么你肯定遇到过问题。明明已经replace的包为何还会去未替换的地址进行搜索和下载？

	golang.org/x/net v0.0.0-20180824152047-4bcd98cce591 // indirect

// indirect，它表示这是一个间接依赖。
间接依赖是指在当前module中没有直接import，而被当前module使用的第三方module引入的包，相对的顶层依赖就是在当前module中被直接import的包。如果二者规则发生冲突，那么顶层依赖的规则覆盖间接依赖。而我们的replace命令只能管理顶层依赖，所以在这里你使用replace golang.org/x/net => github.com/golang/net是没用的，这就是为什么会出现go build时仍然去下载golang.org/x/net的原因。
那么如果我们把 // indirect 去掉了，那么不就变成顶层依赖了吗？答案当然是不行。不管是直接编辑还是go mod edit修改，我们为go.mod添加的信息都只是对go mod的一种提示而已，当运行go build或是go mod tidy时golang会自动更新go.mod导致某些修改无效，简单来说一个包是顶层依赖还是间接依赖，取决于它在本module中是否被直接import，而不是在go.mod文件中是否包含// indirect注释。

replace唯一的限制是它只能处理顶层依赖。

这样限制的原因也很好理解，因为对于包进行替换后，通常不能保证兼容性，对于一些使用了这个包的第三方module来说可能意味着潜在的缺陷，而允许顶层依赖的替换则意味着你对自己的项目有充足的自信不会因为replace引入问题，是可控的。相当符合golang的工程性原则。
也正如此replace的适用范围受到了相当的限制：
* 本地包替换：可以使用本地包替换将生成代码纳入go modules的管理
* 不能访问或过时的包：对于直接import的顶层依赖，可以替换不能正常访问的包或是过时的包
* 相对路径导入包：go modules下import不再支持使用相对路径导入包，例如import "./mypkg"，所以需要考虑replace

## go.sum - 构建状态跟踪文件

也许你知道npm的package-lock.json的作用，它会记录所有库的准确版本，来源以及校验和，从而帮助开发者使用正确版本的包。通常我们发布时不会带上它，因为package.json已经够用，而package-lock.json的内容过于详细反而会对版本控制以及变更记录等带来负面影响。
如果看到go.sum文件的话，也许你会觉得它和package-lock.json一样也是一个锁文件，那就大错特错了。go.sum不是锁文件。更准确地来说，go.sum是一个构建状态跟踪文件。它会记录当前module所有的顶层和间接依赖，以及这些依赖的校验和，从而提供一个可以100%复现的构建过程并对构建对象提供安全性的保证。go.sum同时还会保留过去使用的包的版本信息，以便日后可能的版本回退，这一点也与普通的锁文件不同。所以go.sum并不是包管理器的锁文件。
因此我们应该把go.sum和go.mod一同添加进版本控制工具的跟踪列表，同时需要随着你的模块一起发布。如果你发布的模块中不包含此文件，使用者在构建时会报错，同时还可能出现安全风险（go.sum提供了安全性的校验）。

## go module 迁移

迁移一个已有项目到 go module，其迁移复杂度与项目依赖复杂度成正比，因此需要评估下是否真的需要迁移，当前 GOPATH 管理方式是否已经无法满足开发需求了？
1. 项目是否仍处于开发阶段？如果项目已经停止开发，那么迁移 go module 实际上没有太多益处（除非你的项目被很多其他项目依赖，需要迁移到 go module 以支持其他项目的迁移）；
2. 项目依赖的诸多 pkg 是否已有 module 版本？如果依赖的 pkg 还没有迁移 go module，那么顶层项目的迁移无疑是痛苦的，解决方案是推动底层项目迁移，或者暂时使用本地包代替（搞一个本地的 go module 底层项目版本，效率不高）；

## 参考

* Introduction to Go Modules https://roberto.selbach.ca/intro-to-go-modules/
* Go 语言的 Modules 系统介绍 https://studygolang.com/articles/14389
* 跳出Go module的泥潭 https://colobu.com/2018/08/27/learn-go-module/
* Go Modules 的使用方法 https://studygolang.com/articles/19334
* Go 语言模块化编程 https://www.twle.cn/t/145
* golang包管理解决之道——go modules初探 https://www.cnblogs.com/apocelipes/p/9534885.html
* 再探go modules：使用与细节 https://www.cnblogs.com/apocelipes/p/10295096.html
