---
title: The GNU Privacy Guard
date: 2017-02-03T19:15:35+08:00
tags:
  - Linux
  - 加密
  - GPG
categories:
  - 科技数码
draft: false
---
PGP is useful for two things:
1. Privacy and Security
2. Authenticity

GPG 的公私钥加解密，类比”连城诀“中的解密流程：
- 公钥共享给大家，加密后的内容也可以共享。大家都有「唐诗选辑」，但没人能看懂。
- 只有通过私钥才能从密文中解密出明文。只有通过「唐诗剑法」（没有师傅认证、亲传武功是不行的），才解密出「江陵城南偏西天宁寺大殿佛像向之虔诚膜拜通灵祝告如来赐福往生极乐」（但解密过程用口水翻书始终不够文雅，还埋下了祸根）。
- 当然也有类似凌退思这样“密码字典暴力破解”的方法 :-)，所以我们的 GPG 钥匙长度要设置的长长长一些。
<!--more-->

## Generate GPG Keys

```bash
gpg --gen-key
```
细节参考[GPG入门教程](https://www.ruanyifeng.com/blog/2013/07/gpg.html)，写的非常详细，这里不再赘述。

查看本机公钥（`.gnupg/pubring.gpg`）：`$ gpg --list-keys`  

查看本机私钥（`.gnupg/secring.gpg`）：`$ gpg --list-secret-keys`  

本文假设生成的 GPG Public Key ID 是 `0x5655CA935F09337F`。  

生成公私钥后，可以进行下列配置：
1. Set your key as the default key by entering this line in your ~/.bash_profile (along with any other environment variables to be exported)。设置 shell 变量 `$GPGKEY` ，以后不再需要记住 Key ID ：
```bash
export GPGKEY=0x5655CA935F09337F
gpg --list-keys $GPGKEY
gpg --list-secret-keys $GPGKEY
```
2. Now restart the gpg-agent and set the relevant environment variable:
```bash
killall -q gpg-agent
eval $(gpg-agent --daemon)
export GPGKEY=0x5655CA935F09337F
```
启动`gpg-agent`（功能类似`ssh-agent`），输入一次 GPG 私钥密码以后，`gpg-agent` 自动将私钥密码拷贝到内存中供下次使用，下次不用再输入密码。  
注意：安全性与便捷性之间需要取舍。`gpg-agent / ssh-agent` 固然便捷许多，但是也为他人大开方便之门。如果他人连接进本机，也无需输入密码而使用 GPG / SSH 。

## Export Public Key
```bash
gpg --armor --output key.pub.asc --export $GPGKEY
gpg --output key.pub --export $GPGKEY
```
导出本机的公钥，提供给他人。
* `--armor`, create ASCII armored output; 导出文字版本的 GPG 公钥，故用后缀 `.asc` 表示，这种格式比较常用，可直接公布在网站页面中；
* 无`--armor`参数，导出二进制格式的 GPG 公钥；
## Sends Public Key to Keyserver
除了直接导出公钥提供给他人以外，也可以将公钥发布到钥匙服务器 keyserver，供他人搜索下载：
```bash
$ gpg --keyserver hkp://keys.gnupg.net --send-keys $GPGKEY
gpg: sending key 5F09337F to hkp server keys.gnupg.net

$ gpg --fingerprint seanxp
pub   rsa4096 2016-11-15 [SC]
      429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F
uid           [ unknown] seanxp <iseanxp@gmail.com>
sub   rsa4096 2016-11-15 [E] [expires: 2026-11-13]

$ gpg --fingerprint <key ID> | perl -nE '$.-2 or s/^\h+// and print' | tee fingerprint
```
服务 `keys.gnupg.net` 背后是一组服务器，它们之间的信息同步需要一定的时间，刚刚提交公钥可能不会立即搜索就有结果，只要过一段时间（最长可能要几小时或者几天）就好了。   

公钥服务器会保存发布的公钥，直到其过期`expire`为止。建议不要发布永不过期的公钥，毕竟 `Shit happens` 。或者事前未雨绸缪，生成一份撤销证书线下保存好。  

注意：任何人都可以冒充你的名义上传公钥到 GPG 服务器，所以对方搜到以你的名义发布的公钥，不一定真的是你发布的。为了避免这个问题，你需要公布主钥的指纹。GPG 导入公钥后需要手动设置信任度。这时候对方就可以通过对比计算得到的主钥指纹和你提供的主钥指纹，来确定导入的主钥的合法性。

## Generate Revocation Key
> **A revocation certificate must be generated to revoke your public key if your private key has been compromised in any way.** It is recommended to create a revocation certificate when you create your key. Keep your revocation certificate on a medium that you can safely secure, like a thumb drive in a locked box.
> 
> **Anybody having access to your revocation certificate can revoke your key, rendering it useless.**
> 
> **For security purposes, there is no mechanism in place to revoke a key without a revocation certificate.** As much as you might want to revoke a key, the revocation certificate prevents malicious revocations. Guard your revocation certificate with the same care you would use for your private key.

**Shit happens**，因此要做好防护措施。为自己的公钥设置一份撤销证书，用于将不再安全的公钥从服务器上撤回。

什么情况下公钥会变得“不再安全”？自然是对应的私钥可能已经泄露的情况下，此时别人再用这样的公钥对你发送加密文件，可能被私钥窃取者解密（此时私钥的解锁密码是最后一道防线）。

生成的撤销证书就是一段格式类似文本公钥的字符串，需要严密保存起来。因为任何人都可以拿着这份撤销证书发布到公钥服务器上来撤销你的公钥。然而即使是撤销的证书，也依然可以从公钥服务器中下载。

```bash
gpg --output revoke.asc --gen-revoke $GPGKEY
gpg --import revoke.asc
gpg --keyserver hkp://pgp.mit.edu --send-key [key-ID]
```

1. To revoke your key you need to first create a revocation certificate.
2. (第2步、第3步是将来撤销证书所需要执行的操作) Import your revocation certificate
3. (**不到万不得已，即确定私钥已不再安全的情况下，不要执行此操作**) Upload the key to your keyserver of choice.

## Search Public Key
根据`用户名（UID）`或`用户邮箱（email）`，可以从公钥服务器中搜索其发布的 GPG Public Key。
注意：**任何人都可以用 seanxp 的名义向服务器发布公钥，因此必须审核公钥的指纹是否一致。**
```bash
$ gpg --keyserver hkp://keys.gnupg.net --search-keys seanxp
gpg: data source: http://keyserver.ubuntu.com:11371
(1)     seanxp <iseanxp@gmail.com>
          4096 bit RSA key 5655CA935F09337F, created: 2016-11-15

$ gpg --keyserver hkp://keys.gnupg.net --search-keys 0x5655CA935F09337F
gpg: data source: http://keyserver.ubuntu.com:11371
(1)     seanxp <iseanxp@gmail.com>
          4096 bit RSA key 5655CA935F09337F, created: 2016-11-15
```
这里搜索到一名号称「seanxp」的人发布的公钥（ID: `0x5655CA935F09337F`），为了确认是否是「真•SeanXP」，在 [seanxp.com/about](https://seanxp.com/about/) 页面查看其公布的指纹为
```
Key fingerprint = 429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F
```
其中公钥 ID 就是指纹的后面几位数字，发现后16位十六位进制数字相同(`5655 CA93 5F09 337F`)，**权且相信**是「seanxp」的公钥。

为什么是**权且相信**？因为目前只是后16位数字相同，并不是指纹完全匹配。需要导入搜索到的公钥，打印其指纹，再进行匹配。添加公钥到主机后，打印此公钥的指纹：
``` bash
$ gpg --fingerprint seanxp
pub   rsa4096 2016-11-15 [SC]
      429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F
uid           [ unknown] seanxp <iseanxp@gmail.com>
sub   rsa4096 2016-11-15 [E] [expires: 2026-11-13]
```

指纹匹配成功，说明这是正确的公钥。

注：如果像下面例子（centOS），可以在搜索时查看指纹，可以先匹配指纹再决定是否下载公钥，可以省去不少麻烦。
```
    gpg: searching for "seanxp" from hkp server keys.gnupg.net
    (1)     seanxp <seanxp.com>
              4096 bit RSA key 429D47BBBDB0AA92B8B628F75655CA935F09337F, created: 2016-11-15, expires: 2026-11-13
```
### long-keyid collision
有匹配成功的案例，自然有匹配不成功的案例。下面就是一个公钥后8位数字相同的攻击案例：
GPG 默认显示 Key ID 的后8位数字（即指纹的后8位），那么就有一些别有用心的人，可以暴力生成后8位相同的公钥来实现欺骗目的。 

如下，搜索 `Linus Torvalds` 的 GPG 公钥，现在知其邮箱是 `torvalds@linux-foundation.org`，进行搜索：
```bash
    $ gpg --search-keys torvalds@linux-foundation.org
    gpg: searching for "torvalds@linux-foundation.org" from hkps server hkps.pool.sks-keyservers.net
    (1)     Linus Torvalds <torvalds@linux-foundation.org>
              2048 bit RSA key 00411886, created: 2014-07-21 (revoked)
    (2)     Linus Torvalds <torvalds@linux-foundation.org>
              2048 bit RSA key 00411886, created: 2011-09-20
    Keys 1-2 of 2 for "torvalds@linux-foundation.org".  Enter number(s), N)ext, or Q)uit >
```

搜索到两个具有相同的 Key ID 的公钥！这里就需要进行指纹匹配。在网上搜索，发现[The Linux Kernel Archives - Signatures](https://www.kernel.org/category/signatures.html)提供有`Linus Torvalds`的公钥指纹
```
Developer         Fingerprint
Linus Torvalds    ABAF 11C6 5A29 70B1 30AB  E3C4 79BE 3E43 0041 1886
```

下面的例子体现出 `long Key ID` 的好处，更难进行`long-keyid collision`，后8位容易碰撞相同，后16位碰撞就难的多。
```bash
    gpg: searching for "torvalds@linux-foundation.org" from hkps server hkps.pool.sks-keyservers.net
    (1)     Linus Torvalds <torvalds@linux-foundation.org>
              2048 bit RSA key 0x6211AA3B00411886, created: 2014-07-21 (revoked)
    (2)     Linus Torvalds <torvalds@linux-foundation.org>
              2048 bit RSA key 0x79BE3E4300411886, created: 2011-09-20
    Keys 1-2 of 2 for "torvalds@linux-foundation.org".  Enter number(s), N)ext, or Q)uit >
```

配置显示 `long Key ID` 是在 `~/.gnupg/gpg.conf` 中进行配置：
```conf
    ~/.gnupg/gpg.conf

    # short-keyids are trivially spoofed; it's easy to create a
    # long-keyid collision; if you care about strong key
    # identifiers, you always want to see the fingerprint.
    # Display long key IDs
    keyid-format 0xlong

    # List all keys (or the specified ones) along with their fingerprints
    with-fingerprint
```

## Import Public Key
除了在 GPG 服务器上搜索对方的公钥以外，可以不经过搜索，直接获取指定 Key ID 的公钥：
```bash
gpg --recv-key 0x5655CA935F09337F
gpg --keyserver hkp://pgp.mit.edu --recv-key 0x5655CA935F09337F
```
建议全部使用长 16 位的 Key ID，防止出现后八位碰撞的问题。

也可以直接导入他人的公钥文件，不再通过公钥服务器获取，尤其国内线路经常无法访问到公钥服务器：
```bash
$ wget https://seanxp.com/about/0x5655CA935F09337F-public.key # only for example
$ file 0x5655CA935F09337F-public.key
0x5655CA935F09337F-public.key: PGP public key block Public-Key (old)
$ gpg --import 0x5655CA935F09337F-public.key
$ gpg --fingerprint
```

这里也需要再核对一下指纹，因为这里是通过 `http` 获取的公钥，可能出现`中间人攻击`。中间人既然能篡改你所获取到的公钥，也可能篡改 http 网页上的指纹，因此凡是 http 网页上的公钥和指纹，都要保持怀疑态度。最好是在可靠的源头（https 或 email 联系）确认公钥的合法性。而 `https` 也需要防范中间人攻击，要确保本机的 SSL 证书链的可靠性。
## Sign Key
对于校验指纹无误的公钥，可以用本机私钥进行签名。签名公钥的流程：

```bash
# 校验指纹
gpg --fingerprint seanxp
# 校验成功，本机私钥授权
gpg --sign-key seanxp
gpg --local-user seanxp --sign-key torvalds@linux-foundation.org
# 校验失败，删除错误的公钥
gpg --delete-keys seanxp
```
1. 校验指纹（只有先确认可靠指纹的来源，才能校验本机获取到的公钥指纹的可靠性，再次提醒 http 页面是不可靠的）
2. 指纹校验成功，则用本机私钥对该公钥进行签名（需要本机私钥授权，即需要输入本机私钥的密码，可防止他人授权）
3. 校验失败，则删除错误的公钥。

为什么要用本机私钥对公钥进行签名呢？

防止他人篡改本机的可靠公钥，如果他人想用虚假公钥替换可靠公钥，下次使用该公钥，系统会提示公钥不可靠（所有未签名的公钥都会提示不可靠的信息）。

经过 `gpg --sign-key` 签名的公钥，成为了 `trust: unknown validity: full`，即现在确认该公钥是有效的（validity），但是还未信任该公钥。信任公钥需要用到交互命令`--edit-key`。

## Edit Key

```bash
gpg --edit-key seanxp
```

编辑公钥，有很多功能：

* fpr, show key fingerprint
* sign, sign selected user IDs
* trust, change the ownertrust
* enable, enable key
* disable, disable key
* passwd, change the passphrase

对于已经校验指纹无误，并已经通过 `gpg --sign-key` 签名的公钥，可以在编辑公钥下设置其信任度：
```bash
$ gpg --edit-key torvalds@linux-foundation.org
    ...
    gpg> trust
    pub  2048R/0x79BE3E4300411886  created: 2011-09-20  expires: never       usage: SC
                                   trust: unknown       validity: full
    sub  2048R/0x88BCE80F012F54CA  created: 2011-09-20  expires: never       usage: E
    [  full  ] (1). Linus Torvalds <torvalds@linux-foundation.org>

    Please decide how far you trust this user to correctly verify other users' keys
    (by looking at passports, checking fingerprints from different sources, etc.)

      1 = I don't know or won't say
      2 = I do NOT trust
      3 = I trust marginally
      4 = I trust fully
      5 = I trust ultimately
      m = back to the main menu

    Your decision? 4

    pub  2048R/0x79BE3E4300411886  created: 2011-09-20  expires: never       usage: SC
                                   trust: full          validity: full
    sub  2048R/0x88BCE80F012F54CA  created: 2011-09-20  expires: never       usage: E
    [  full  ] (1). Linus Torvalds <torvalds@linux-foundation.org>
    Please note that the shown key validity is not necessarily correct
    unless you restart the program.

    gpg> quit
```

关于信任程度的设置，参考[Reddit - Question: clarification about trust/validity](https://www.reddit.com/r/GnuPG/comments/2knpbo/question_clarification_about_trustvalidity/)。

还可以更改本机私钥的密码：
```bash
$ gpg --edit-key $GPGKEY
    ...
    gpg> passwd
    ...
    gpg> save
```
## Encrypt
GPG 的一大用处，就是用他人的公钥加密文件，通过不可靠的网络传输过去，由对方的私钥解密，完成通信任务。 这里用自己的公钥加密，模拟练习（自娱自乐），并用自己的私钥解密。
```bash
$ echo "Hello world" > hello.txt
$ cat -A hello.txt
Hello world$
$ md5 hello.txt
f0ef7081e1539ac00ef5b761b4fb01b3 hello.txt

$ gpg --armor --recipient seanxp --output He110.txt --encrypt hello.txt
$ file He110.txt
He110.txt: PGP message Public-Key Encrypted Session Key (old)
```
* `--armor`，表示输出文本文件格式。如果要加密二进制文件，则忽略此参数；
* `--recipient`，指定信息的接收者（recipient）公钥的uid，可以是名字也可以是email地址；
* `--output`，指定输出（即加密后）的文件名；
* `--encrypt`，执行加密（encrypt）操作；

除了这样的长选项，还有简单选项，对应的命令为：
```bash
gpg -a -r seanxp -o He110.txt -e hello.txt
```

这样就生成了一份用 seanxp 的公钥所加密的文件，GPG 的算法确保只有 seanxp 的私钥可以解密出正确的数据。
除了加密单个文件外，还可以对文件夹进行压缩后加密：
```bash
$ tar -cvz backup/ | gpg -e -r [key-ID] -o backup.tgz.gpg
$ tar -cvj backup/ | gpg -e -r [key-ID] -o backup.tar.bz2.gpg
$ file backup.tgz.gpg
backup.tgz.gpg: PGP RSA encrypted session key - keyid: 318B6A40 48F76F84 RSA (Encrypt or Sign) 4096b .
```

`keyid: 318B6A40 48F76F84 RSA (Encrypt or Sign) 4096b`，表示该文件是用公钥`0x406A8B31846FF748`（与keyid的字节序相反，但确实是同一个公钥）加密的。 该公钥是 seanxp 公钥`0x5655CA935F09337F`的从钥的公钥。
```bash
$ gpg --list-public-keys seanxp
pub   4096R/0x5655CA935F09337F 2016-11-15
    Key fingerprint = 429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F
uid                 [ultimate] seanxp <seanxp.com>
sub   4096R/0x406A8B31846FF748 2016-11-15 [expires: 2026-11-13]
```
生成 GPG 钥匙，会生成两对公私钥，即四把钥匙，用处不同，稍后详解。

## Decrypt
用公钥加密的数据，可以用对应的私钥解密：
```bash
    $ rm hello.txt
    $ gpg --output hello.txt --decrypt He110.txt

    You need a passphrase to unlock the secret key for
    user: "seanxp <seanxp.com>"
    4096-bit RSA key, ID 0x406A8B31846FF748, created 2016-11-15
             (subkey on main key ID 0x5655CA935F09337F)

    gpg: encrypted with 4096-bit RSA key, ID 0x406A8B31846FF748, created 2016-11-15
          "seanxp <seanxp.com>"

    $ file hello.txt
    hello.txt: ASCII text
    $ cat -A hello.txt
    Hello world$
    $ md5 hello.txt
    f0ef7081e1539ac00ef5b761b4fb01b3 hello.txt
```
`He110.txt` 是用子公钥 `0x406A8B31846FF748` 加密，也是用子私钥解密的。
对于加密压缩文件夹的解密方法：
```bash
$ gpg --decrypt backup.tgz.gpg | tar -xz
$ gpg --decrypt backup.bz2.gpg | tar -xj
```
## Signature
* [An introduction to Digital Signatures, by David Youd](https://www.youdzone.com/signature.html)
* [数字签名是什么？- 阮一峰的网络日志](https://www.ruanyifeng.com/blog/2011/08/what_is_a_digital_signature.html)

既然文件是通过`不可靠`的网络传输的，很多时候可能被篡改替换，因此需要用到数字签名。 [例如在网上下载的 linux kernel 需要验证数字签名是否有效。](https://www.kernel.org/category/signatures.html)

注意区别加密与签名：
* 加密是对文件进行加密操作，用**子公钥**`0x406A8B31846FF748`进行 RSA 加密，确保只有对应的子私钥可以解密；
* **加密的数据无需签名**，因为如果加密的数据在传输过程中被篡改，解密时会提示`gpg: CRC error;`校验错误；
* **对文件签名，不会对原文件进行任何处理**，只是对原文件生成数字摘要并用私钥加密生成数字签名；
* 如果只签名不加密，原文件在传输过程中会被其他人看到，但是可以保证该文件在被修改的情况下无法通过数字签名校验；
* 加密确保`只有你能看到这个文件`，签名确保`只有我能写出这个文件`。

### detached signature
对于分散在多个渠道提供下载的资源（无需加密传输的大文件），最好的方法就是生成一个独立于下载文件的数字签名文件供他人下载校验。很多软件开发者也会在其软件官方网站提供签名文件供校验。
例如对 `hello.txt` 生成分离的签名文件：

```bash
    $ gpg --armor --detach-sign hello.txt

    You need a passphrase to unlock the secret key for
    user: "seanxp <seanxp.com>"
    4096-bit RSA key, ID 0x5655CA935F09337F, created 2016-11-15

    $ file hello.txt.asc
    hello.txt.asc: PGP signature Signature (old)
```

独立生成一个 `hello.txt.asc` 的签名文件，后缀名 `asc` 表示该文件是 ASCII 码形式的。 因为是分离的签名，需要把原信息文件 `hello.txt` 连同签名文件 `hello.txt.asc` 一起寄给他人，交由他人进行检验。
### clear text signature
对于简单文本，可以使用`clearsign`的独立（不修改原文件）不分离（原文本与数字签名写在同一文件中）式数字签名：
```bash
	$ gpg --clearsign hello.txt

    $ cat hello.txt.asc
    -----BEGIN PGP SIGNED MESSAGE-----
    Hash: SHA512

    Hello world
    -----BEGIN PGP SIGNATURE-----

    iQIcBAEBCgAGBQJYlVHxAAoJEFZVypNfCTN/wMEP/1HNhw7YUAIGEjkLXlALgCRj
    QLiBxQtzNszmGtzsIaPXRTt4aOxmicmNyLQ7JHImN372LnvYkYDV2PY/ZIfujGpb
    qpTE3kCTEgS55SK/zfLEA+njq1LzCsSuPUUEoIO8DXhg1L+Ktf4GhlupSWI3X/iS
    JzEszetFJ/u2650JQPofY2cWeetrY9j7UdnjqtSJQCrA9be9hcBDoepCzfZg62Ae
    hnuw8sUayE6kwoJKA5aMNcrbN5qxhvUVULJKxhK2cCzi3vatBzjnnqKeFBfz64V8
    LiM3Qk3AbKeE+2P3ZorbXgD265dYDcHTMBCzMgjKoFUvoOlrF+ZeMv7HYcQNOHx7
    dEmx2VEhInwdB9snhBokH8KsFlWsPIpLbbarwDL56jUjC4jrDW8EF05dJLXCfALV
    8M2MVD513tVSx/ktSYyY2h+mBbrfAo5J54+KZN/NJpan/woP0ooWNTyey3T/y/sv
    OZZuyg7w0Hl3j4bVnji++DcJhkwbfq32yvzDi0BLcEATNQRO5h5FifUSg3eV8W0f
    U8p1NUrd5W7in1ne1x9EMZkrFfzkLP7rYxHkmZ+KMW4fNGMFjQGi1YAQN+S0mNCM
    AGuZpLRb0MgudFzotPuyWH5D9hHyWpjF2qHrK7an9jTgtE/eemU4l00frwnBc9a1
    bl9M0p7XCJsh2xOHx72I
    =5P7S
    -----END PGP SIGNATURE-----
```

根据 `hello.txt` 生成 `hello.txt.asc` 文件，此签名文件中已经包含有 `hello.txt` 的数据。 只需要将此签名文件寄给他人即可。他人校验数字签名的同时即可分离出原数据文件。

### binary signature
使用`--sign`选项，即可生成最简单的数字签名：

```bash
    $ gpg --sign hello.txt
    $ file hello.txt.gpg
    hello.txt.gpg: data

    $ gpg helle.txt.gpg
```

* 独立的签名文件 `hello.txt.gpg`
* 文件数据不加密（可以在`hello.txt.gpg`文件中看到`Hello world`）
* 二进制数字签名
### summary
* 使用`--detach-sign`选项，生成分离的签名文件；
* 使用`--sign`选项，生成不分离的签名文件，与`--detach-sign`选项相反；
    * 加上`--armor`选项，则生成 ASCII 格式的数字签名（hello.txt.asc: PGP message Compressed Data），无法看出原文件的数据，但是解密后可以得到原文件数据；
    * 不加`--armor`选项，则生成二进制格式的数字签名（hello.txt.gpg: data），可以看到其中的原文件数据；
* 使用`--armor`选项，生成 ASCII 格式的签名；
* 使用`--clearsign`选项，可以省略`--armor`选项，生成独立分离式文本签名；

另外，如果本机中用于签名的私钥不止一个时，需要指定签名所用的私钥：
```bash
    --local-user,-u: Use name as the key to sign with. Note that this option overrides --default-key.
    $ gpg -u $GPGKEY --sign hello.txt
```

### verify
拿到别人的数字签名文件，需要用其公钥进行校验（别人用私钥生成签名文件，那就用对应的公钥校验签名文件）。 对于 `.gpg` 后缀的签名文件，直接使用`gpg xxx.gpg`命名校验其数字签名，并且能分离出原文件。

```bash
    $ gpg -u $GPGKEY --sign hello.txt
    $ file hello.txt.gpg
    hello.txt.gpg: data
    $ rm hello.txt
    
    $ gpg hello.txt.gpg
    gpg: Signature made Sat Feb  4 12:34:13 2017 CST
    gpg:                using RSA key 0x5655CA935F09337F
    gpg: Good signature from "seanxp <seanxp.com>" [ultimate]
    Primary key fingerprint: 429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F

	$ cat -A hello.txt
    Hello world$
```

对于使用 `--detach-sign` 签名的签名文件，使用 `gpg --verify` 命令进行校验。因为是分离的数字签名文件，因此原文件也必须存在，gpg 会对原文件进行 hash 处理，与解密数字签名文件中的 hash 进行对比。
```bash
    $ gpg -u $GPGKEY --armor --detach-sign hello.txt
    $ file hello.txt.asc
    hello.txt.asc: PGP signature Signature (old)

    $ rm hello.txt
    $ gpg --verify hello.txt.asc
    gpg: no signed data
    gpg: can not hash datafile: No data

    $ echo "Hello world" > hello.txt
    $ gpg --verify hello.txt.asc
    gpg: assuming signed data in 'hello.txt'
    gpg: Signature made Sat Feb  4 12:36:14 2017 CST
    gpg:                using RSA key 0x5655CA935F09337F
    gpg: Good signature from "seanxp <seanxp.com>" [ultimate]
    Primary key fingerprint: 429D 47BB BDB0 AA92 B8B6  28F7 5655 CA93 5F09 337F
```

对于不分离的数字签名文件 `--clearsign`，不需要原文件，因为签名文件中已包含签名文件的数据，可以使用`gpg --verify`直接校验。

## Encrypt & Signature
同时进行加密和签名操作：
```bash
    $ gpg --local-user [发信者ID] --recipient [接收者ID] --armor --sign --encrypt hello.txt

    $ gpg --local-user $GPGKEY --recipient torvalds@linux-foundation.org --armor --sign --encrypt hello.txt
    $ file hello.txt.asc
    hello.txt.asc: PGP message Public-Key Encrypted Session Key (old)
```

## GPG Subkeys
* [GPG 密鑰的「正確」用法](https://blog.theerrorlog.com/using-gpg.html)
* [为什么我们需要三个新的子密钥](https://mechanus.io/ke-neng-shi-zui-hao-de-yubikey-gpg-ssh-zhi-neng-qia-jiao-cheng/)
* [多对subkey](https://www.mawenbao.com/note/gnupg.html)

GPG 密钥环并不只有一对公钥和私钥，如果称公钥和其对应的私钥为一个密钥对的话，那么一个 GPG 密钥环可以拥有很多个密钥对，每一个密钥对都由一个钥匙号（key ID）标识，被称为钥匙。其中有一个钥匙拥有签名其他钥匙的功能（可以在密钥环中创建钥匙），这个钥匙被称为主钥，其他的钥匙则被称为从钥。

GPG 列出的每个密钥环第一行一定是主钥，其余的则为从钥。 一个GPG 密钥环一共有四种类型的密钥：

| 属性 | 代表 | 含义 |
| :--: | :--: | :--: |
| sec | SECret key | 主钥的私钥 |
| pub | PUBlic key | 主钥的公钥 |
| ssb | Secret SuBkey | 从钥的私钥 |
| sub | public SUBkey | 从钥的公钥 |

至于这些钥匙的作用可以查看它们的功能，常用的功能有三种：

| 功能 | 代表 | 含义 |
| :--: | :--: | :--: |
| S | Signing | 签名和校验签名 |
| E | Encryption | 加密和解密信息 |
| C | Certification | 认证钥匙 |

* E = encrypt/decrypt (decrypt with your private key of a message you received)
* S = sign (sign data. For example a file or to send signed e-mail)
* C = certify (sign another key, establishing a trust-relation)
* A = authentication (log in to SSH with a PGP key; this is relatively new usage)

最后一项功能 authentication ，可以将 GPG 生成 SSH 对应的公私钥，并用于 SSH 登录。
注意功能是针对一对钥匙而言的，由其中的公钥和私钥共同完成。其中加密和解密分别由钥匙的公钥和私钥完成，签名和验证则分别由私钥和公钥完成。

一般地，GPG 密钥环中钥匙的公钥需要公布到网络上，也就意味着：
* Encryption，所有人都能用你公布的公钥加密信息，加密后的信息只有持有私钥的你才能够解密。
* Signing，你可以使用自己持有的私钥签名信息，所有人都能够用你公布的公钥验证签名的合法性。
* Certification，你可以用自己持有的私钥认证他人的公钥，从而建立信任关系。

默认情况下，GPG 生成的密钥环将主密钥（master key）和子密钥（sub key）放在一起，**主密钥用于签名和验证（usage: SC），从密钥用于加解密（usage: E）**。前面给出的例子中，用于加密的密钥是 sub key，签名的密钥是 master key。

```
    pub  4096R/0x5655CA935F09337F  created: 2016-11-15  expires: never       usage: SC
    sub  4096R/0x406A8B31846FF748  created: 2016-11-15  expires: 2026-11-13  usage: E
```

**使用子密钥的好处在于能够更换签名或者加密密钥，而不破坏主密钥的关系网络和Key ID**。除了默认生成的用来加密的子密钥外，还可以添加更多的子密钥，用来签名或者用来加密。它们的公钥会随着主密钥的公钥发布，方便其他人验证或者加密。

为保证 master private key 的安全，将其放到离线的其他介质（比如U盘），并从钥匙环中删除。同时为方便日常使用，需要分别创建一个负责加密的 subkey（默认已有）和一个负责签名的 subkey。

日常加密和签名操作都通过 subkeys 进行，需要使用 master private key 时（吊销/添加 subkeys，签收他人公钥），挂载U盘然后执行如下操作就能看到 master private key。

实际上这种用途，更安全的方法是使用一块 [VeraCrypt](https://veracrypt.codeplex.com/) 全盘加密的 U 盘。每次需要使用 master private key 时，插入 U 盘，VeraCrypt 全盘解密，之后使用 `gpg --homedir` 选型指定路径，执行完命令后卸载 U 盘。

    $ gpg --homedir /path/to/your/usb-drive/_gnupg --list-secret-keys

## Backup Keys
建议使用 VeraCrypt 隐藏盘，100K 的大小，存放公私钥及吊销证书，存放在多个不同地方的隐藏文件夹下 。

查看并导出公私钥：
```
$ gpg --list-keys
$ gpg -ao 0x5655CA935F09337F-public.key -export 0x5655CA935F09337F

$ gpg --list-secret-keys
$ gpg -ao 0x5655CA935F09337F-private.key --export-secret-keys 0x5655CA935F09337F
```

将备份的公私钥文件导入新电脑：
```
$ gpg --import _something_-public.key
$ gpg --import _something_-private.key
```

## Other
### RSA
* [RSA算法原理（一）](https://www.ruanyifeng.com/blog/2013/06/rsa_algorithm_part_one.html)
* [RSA算法原理（二）](https://www.ruanyifeng.com/blog/2013/07/rsa_algorithm_part_two.html)

### PGP(Pretty Good Privacy)
* [Pretty Good Privacy - Wikipedia](https://en.wikipedia.org/wiki/Pretty_Good_Privacy)
* [良好隐私密码法](https://www.wikiwand.com/zh-hans/%E8%89%AF%E5%A5%BD%E9%9A%B1%E7%A7%81%E5%AF%86%E7%A2%BC%E6%B3%95)
### Web of Trust
[Web of trust - Wikipedia](https://en.wikipedia.org/wiki/Web_of_trust)
PGP 采用信任网结构（Web Of Trust）的分布式密钥管理，这种密钥管理体制下没有密钥证书管理机关（CA），用户之间的身份认证问题是通过介绍人（introducer）来解决的。所有的用户产生并分发他们自己的公开密钥，用户通过相互对公开密钥签名以创建一个包含所有 PGP 用户的信任网（Web Of Trust）。简单地说就是，在信任网中，没有大家都信任的中心权威机构，用户以各自为中心，相互认证公钥，相互签名公钥证书。这些签名使得用户的公钥彼此相连，形成自然的网状结构，也就是所谓的信任网。
### Macbook GPG issue
Macbook 下，出现下面问题：

    gpg-agent[30845]: command get_passphrase failed: No such file or directory
    gpg: problem with the agent: No such file or directory
    gpg: decryption failed: No secret key

即需要输入 GPG 私钥密码的时候，没有弹出输入框，而是直接默认输入失败。
[解决方案](https://github.com/IJHack/qtpass/issues/156)，可以通过 [GPGTools](https://gpgtools.org/) 的 pinentry-mac (pinentry for GPG on Mac) 解决：

    brew install pinentry-mac
    echo "pinentry-program /usr/local/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf

## Reference
* [The GNU Privacy Guard](https://www.gnupg.org/)
* [GPG 维基百科](https://www.wikiwand.com/zh-hans/GnuPG)
* [GPG 入门教程](https://www.ruanyifeng.com/blog/2013/07/gpg.html)
* [GPG Quick Start](https://www.madboa.com/geek/gpg-quickstart/)
* [Gnu Privacy Guard Howto](https://help.ubuntu.com/community/GnuPrivacyGuardHowto)
* [ArchLinux GunPG](https://wiki.archlinux.org/index.php/GnuPG)
* [Why Use GnuPG?](https://www.phildev.net/pgp/gpgwhy.html)