---
title: HomeLab 搭建指南 (四)：家庭影院 —— Ubuntu 核显直通与 Jellyfin 硬件解码详解
date: 2025-12-20T11:00:00+08:00
tags:
  - HomeLab
  - PVE
  - Linux
  - Jellyfin
categories:
  - 科技数码
draft: false
---
在 HomeLab 中搭建媒体服务器是很多人的核心需求。而硬件视频解码（Hardware Transcoding）可以大幅降低 CPU 负载，让一台低功耗的迷你主机也能流畅处理多路 4K 电影转码。

本文将以 **PVE 9.1** 宿主机和 **AMD 680M** 核显为例，详细记录如何实现核显的彻底隔离、直通给 Ubuntu 24.04 虚拟机，并在 Docker 中部署 Jellyfin 实现丝滑的硬解体验。
<!--more-->

## 1. 前言：打造高效能影音中心

### 为什么需要硬件解码？

视频转码是计算密集型任务。如果你尝试用 CPU 软解一部 4K HEVC 编码的电影，CPU 占用率会迅速飙升至 100%，导致系统卡顿甚至崩溃。而通过核显（iGPU）硬解，显卡内部的专用电路（如 Intel 的 QuickSync 或 AMD 的 VCN）会承担全部压力，CPU 占用通常不到 10%。

**对比数据：**
- **CPU 软解 4K HEVC**：CPU 占用 80-100%，功耗高，并发能力差
- **核显硬解 4K HEVC**：CPU 占用 < 10%，功耗低，可同时处理多路转码

### 硬件环境

- **CPU**: AMD Ryzen 7 6800H (集成 Radeon 680M 核显，RDNA2 架构)
- **PVE 版本**: 9.1.1
- **虚拟机 OS**: Ubuntu 24.04.1 LTS

---

## 2. PVE 宿主机环境准备 (安全隔离阶段)

这是最关键的一步。由于 AMD 迷你主机（如零刻、摩方等）的 IOMMU 分组往往比较混乱，如果直接直通，容易导致宿主机在虚拟机启动时崩溃（Kernel Panic）。

### A. 修改 GRUB 引导参数

编辑 `/etc/default/grub`：

```bash
vi /etc/default/grub
```

修改 `GRUB_CMDLINE_LINUX_DEFAULT`：

```bash
#GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt video=efifb:off initcall_blacklist=sysfb_init pcie_acs_override=downstream,multifunction pci=nommconf vfio-pci.ids=1002:1681"
```

**关键参数解析：**

- `iommu=pt`: 开启透传模式，提升性能与兼容性
- `video=efifb:off`: 禁止宿主机占用显卡显示控制台，防止抢占
- `initcall_blacklist=sysfb_init`: 阻止系统帧缓冲初始化
- `pcie_acs_override=downstream,multifunction`: **核心参数**。强制拆分 IOMMU 分组，防止核显与 NVMe 硬盘控制器绑定在一起导致虚拟机启动时带走硬盘
- `pci=nommconf`: **核心参数**。解决 AMD 迷你主机在 PCI 总线重置时的内存冲突，防止死机
- `vfio-pci.ids=1002:1681`: 指定 680M 的硬件 ID，让宿主机启动时直接隔离（请根据你的实际硬件 ID 修改）

**如何查找你的核显硬件 ID：**

```bash
lspci -nn | grep -i vga
# 输出示例：
# e5:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] [1002:1681] (rev c7)
# 最后的 [1002:1681] 就是硬件 ID
```

### B. 驱动黑名单

确保 PVE 不加载显卡驱动。编辑 `/etc/modprobe.d/pve-blacklist.conf`：

```bash
vi /etc/modprobe.d/pve-blacklist.conf
```

添加内容：

```bash
blacklist amdgpu
blacklist radeon
```

**注意**：对于 N100 等新卡，可能不需要这步，视实际情况而定。如果宿主机需要显示输出，则跳过此步骤。

### C. 更新并重启

```bash
update-grub
update-initramfs -u
reboot
```

**重要提醒**：执行 `update-initramfs -u` 是必须的，否则驱动黑名单可能不会生效。

### D. 验证隔离是否成功

重启后，在 PVE 终端输入：

```bash
lspci -k -s e5:00.0
```

预期输出：

```
e5:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] (rev c7)
	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Device 0124
	Kernel driver in use: vfio-pci
	Kernel modules: amdgpu
```

如果看到 `Kernel driver in use: vfio-pci`，而不是 `amdgpu`，那么恭喜你，现在绝对安全了。即使虚拟机配置错误，也不会导致宿主机崩溃，因为显卡已经完全属于 VFIO 了。

**注意**：请将 `e5:00.0` 替换为你实际的 PCI 设备地址（可通过 `lspci | grep -i vga` 查看）。

### E. PVE 黑屏现象解析

**提示**：完成上述隔离后，PVE 宿主机的 HDMI 物理输出通常会出现“黑屏”或“画面停滞”的现象，这是正常且预期的现象。其原因是 grub 参数中配置了 `video=efifb:off` 和 `vfio-pci.ids=...`：

- `video=efifb:off`：彻底关闭了宿主机的基础帧缓冲显示输出；
- `vfio-pci.ids=...`：启动时直接把核显控制权交给 VFIO 隔离，并不再由宿主机系统接管。

**效果：**
- 开机过程中，显示器往往停留在最后一行启动信息，或者直接黑屏、无信号；
- 这是“隔离彻底且安全”的标志。PVE 宿主机此时不会加载与显卡相关的驱动模块，从根本上杜绝了显卡驱动冲突导致的系统崩溃风险。

**注意后续管理方式变更：**
- 物理机上的显示器和键盘此时已无法用于 PVE 的直接管理，后续管理请务必通过 Web 控制台或 SSH 进行远程操作。

这一现象无需担心，恰恰说明你的核显隔离与直通配置非常成功。

---

## 3. 虚拟机创建与硬件直通 (VM Setup)

在 PVE Web 界面创建或修改虚拟机：

### 虚拟机核心配置建议：

- **开机自启（Start at boot）**：建议设置为 No  
  🚨 说明：在核显直通调试完全成功，并确认 PVE 不会崩溃前，请务必保持关闭状态，避免虚拟机异常导致宿主机宕机。

- **Machine（机型）**：选择 `q35`  
  支持现代 PCIe 总线，便于硬件直通。

- **BIOS**：选择 `OVMF (UEFI)`  
  680M 这类新核显必须运行在 UEFI 启动模式下，传统 BIOS 模式无法正常驱动。

- **Display（显示）**：选择 `none`  
  防止虚拟显卡与直通显卡产生冲突，忘记设置这一项极易导致 PVE 宿主机挂掉，务必注意。

- **CPU 设置**：例如 `8 (1 sockets, 8 cores) [host]`  
  - 类型（Type）：请务必选择 `host`
  - 插槽数量（Sockets）：通常设为 1，即"CPU 1 sockets"，对应移动端 APU 的单封装结构（如 FP7）
    ⚠️ 若插槽设错，虚拟机会无法启动或直接崩溃
  - 核心数（Cores）：根据实际 APU 性能调整分配，建议至少 4 核

- **内存（Memory）**：推荐至少 8GB，例如 `12.00 GiB [balloon=0]`  
  - `balloon=0` 为强制关闭内存动态分配。PCI 直通场景下，内存必须为静态分配，否则会影响 IOMMU 映射，导致显卡驱动加载失败或宿主机 Kernel Panic。在 PVE Web 界面中，可以在虚拟机选项（Options）中设置 "Ballooning Device" 为禁用。

- **硬盘（Hard Disk）**：建议分配至少 20GB 以上，按实际需求可适当增加。

### 添加 PCI 设备（核心步骤）：

1. `Hardware` → `Add` → `PCI Device`
2. 选择对应的 Raw Device（本文示例是 `0000:e5:00.0`，请根据你的实际情况选择）
3. **勾选选项**：
   - `ROM-Bar`: 勾选（提供显卡 ROM 信息）
   - `PCI-Express`: 勾选（使用 PCIe 总线）
4. **不勾选选项**：
   - `Primary GPU`: **不勾选**（仅作为计算/转码卡，不作为主显卡，稳定性更高）
   - `All Functions`: **不勾选**（减少总线复杂度）

---

## 4. Ubuntu 内部驱动配置 (Guest OS Driver)

进入 Ubuntu 虚拟机后，我们需要确保系统能正确识别并驱动这块"外来"显卡。

### A. 设备识别与核显接管确认

进入 Ubuntu 虚拟机后，首先需要确认系统是否成功识别并接管核显。依次执行以下步骤：

```bash
# 1. 检查显卡相关设备节点
ls /dev/dri
# 期望结果：应能看到 card0 和 renderD128（不同硬件和驱动环境下，也可能是 card1 和 renderD129）。
# 只要出现 renderDxxx 这样的节点，基本可以确定核显已经被 Ubuntu 所驱动。

# 坏结果示例（没有找到显卡，请执行下面的第二步安装驱动）：
# ls: cannot access '/dev/dri': No such file or directory

# 2. 如 /dev/dri 下没有 render 相关节点，可进一步查询 PCI 设备状态
lspci -nn | grep -i vga
# 正常情况下会看到类似如下输出，代表已正确识别显卡：
# 01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] [1002:1681] (rev c7)

# 3. 查看核显所用的内核驱动情况
lspci -k -d 1002:
# 期望输出如下，重点关注 "Kernel driver in use: amdgpu" 字样：
# 01:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] (rev c7)
#     Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M]
#     Kernel driver in use: amdgpu
#     Kernel modules: amdgpu
```

如果以上三步均达到预期结果，说明 Ubuntu 虚拟机已经成功识别并完全接管了通过 PCI 直通的核显设备，可以直接进行后续配置（权限管理）。

如果在第 1 步未能看到相关显卡节点，则需继续执行第 2 步进一步确认。若仍未识别到核显，请按下文"更新显卡驱动"进行操作，排查驱动或固件缺失问题。如果第 1 步已确认显卡存在，则可直接跳过驱动安装步骤，进入"权限管理"部分。

### B. 更新显卡驱动（找不到显卡时执行）

Ubuntu 24.04 默认可能缺少 RDNA2 的固件，需要手动补全：

```bash
sudo apt update
sudo apt install linux-firmware linux-modules-extra-$(uname -r) -y
sudo update-initramfs -u
sudo reboot
```

重启后验证：

```bash
# 查看内核驱动
lspci -k -d 1002:
# 预期输出：Kernel driver in use: amdgpu

# 查看渲染设备
ls -l /dev/dri
# 预期输出：应该看到 renderD128 或类似设备
```

### C. 权限管理（大坑预警）

为了让 Docker 容器内的 Jellyfin 能够访问显卡，必须获取 `render` 组的 GID：

```bash
getent group render | cut -d: -f3
# 记下这个数字，例如 993
```

**为什么需要这个？** 如果不通过 `group_add` 映射权限，Docker 容器可能无法读取 `/dev/dri/renderD128`，导致硬件解码失败。

---

## 5. Docker 与 Jellyfin 部署

### A. 安装 Docker

```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 添加用户到 docker 组
sudo usermod -aG docker $USER
newgrp docker

# 验证安装
docker --version
```

### B. 安装 Docker Compose

```bash
sudo apt install docker-compose -y
```

### C. Docker Compose 配置

推荐使用 **nyanmisaka/jellyfin**，它内置了更完善的硬件加速支持。

创建目录结构：

```bash
mkdir -p /srv/jellyfin/{config,cache}
```

创建 `docker-compose.yml`：

```yaml
services:
  jellyfin:
    image: nyanmisaka/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - 8096:8096
      - 8920:8920
      - 7359:7359/udp
      - 1900:1900/udp
    volumes:
      - /srv/jellyfin/config:/config
      - /srv/jellyfin/cache:/cache
      - /your/media/path:/media:ro  # 修改为你的媒体文件路径
      # 如果使用 NFS，可以取消下方注释并配置：
      # - media_nfs:/media:ro
    devices: # 硬件直通
      - /dev/dri:/dev/dri # 映射整个驱动目录
    group_add:
      - "993" # render 组 GID（请替换为你实际的 GID）
    environment:
      - TZ=Asia/Shanghai  # 时区设置，根据实际情况修改
      - PUID=0  # 用户 ID，可根据需要调整
      - PGID=0  # 用户组 ID，可根据需要调整

# 如果使用 NFS 挂载媒体文件，取消下方注释：
# volumes:
#   media_nfs:
#     driver: local
#     driver_opts:
#       type: nfs
#       o: addr=your-nas-ip,nolock,nfsvers=4,soft,ro
#       device: ":/your/nfs/path"
```

### D. 启动 Jellyfin

```bash
cd /srv/jellyfin
docker-compose up -d
```

### E. 访问 Jellyfin

打开浏览器访问：

```
http://your-ip:8096
```

按照向导完成初始设置。

---

## 6. Jellyfin 硬件解码配置

### A. 进入管理界面

登录后，进入：`控制台` → `播放`

### B. 启用硬件加速

在 "Hardware acceleration" 部分：

- **硬件加速**: 选择 `Video Acceleration API (VAAPI)`
- **VAAPI 设备**: 填写 `/dev/dri/renderD128`

### C. 配置转码选项

在 "Transcoding" 部分：

- **Enable hardware encoding**: 启用
- **Hardware decoding**: 启用
- **Enable tone mapping**: 开启色调映射（实现 HDR 转 SDR 播放时不偏色，具体选项见下方 F 小节）

### D. 配置硬件解码选项

在硬件解码选项中，建议将 AMD 680M 支持的所有格式全部勾选。AMD 680M 对 H264、HEVC、VP9、AV1（包括 10bit）均具备出色的硬件解码能力。如此设置能确保绝大部分视频格式均由核显负载解码，极大降低 CPU 压力。

- `H264`
- `HEVC (H.265)`
- `VP9`
- `AV1`（680M 支持全格式硬解）

### E. 配置编码格式选项

- **启用 HEVC 硬件编码**：勾选后，转码输出的视频文件体积更小，画质表现优秀。对于 680M 核显来说，HEVC 编码基本没有压力，能够高效完成任务。
- **启用 AV1 硬件编码**：这是 680M 的一大卖点。680M 属于少数原生支持 AV1 硬编的核显之一。如果你的播放终端（如最新的手机、浏览器或智能电视）支持 AV1，强烈建议开启该项，可以在保证画质的同时大幅降低带宽消耗。

**注意：兼容性陷阱！**

很多用户主要在网页端（Html Video Player）观看视频。尽管核显可以轻松输出 HEVC/AV1 流，但市面上的主流浏览器（Chrome、Firefox、老版 Edge 等）对网页中实时转码的 HEVC/AV1 支持非常有限。结果就是 Jellyfin 发出 HEVC/AV1 流，浏览器却无法正常解码，报错"客户端不支持该媒体"。

关闭 HEVC/AV1 两个编码选项后，Jellyfin 会采用 H264 软/硬件编码，这是兼容性最广的解决方案。几乎所有的浏览器、移动设备、电视都能完美播放 H264 视频。尽管 H264 压缩率不如 HEVC，但能确保"万无一失地放得出来"。

**配置建议：该怎么选？**

- **网页浏览为主**：建议关闭 HEVC/AV1 编码，只保留 H264。这样在浏览器端观影无需担心兼容性，680M 处理 H264 转码压力极小。
- **专用客户端为主**（如 Jellyfin Media Player、Jellyfin App for 安卓电视盒子等）：这些 App 自带解码器，往往支持 HEVC 硬解。可以放心勾选“允许 HEVC 编码”，画质和效率更优，带宽占用也会更低。
- **AV1 编码**：目前 AV1 解码器普及率较低，仅最新设备和少量应用支持。如不确定终端是否兼容 AV1，请勿开启此选项，避免播放失败。

总之，优先兼容性就选 H264，追求高效和新格式可逐步尝试 HEVC、AV1，务必根据你的播放场景灵活调整。

### F. 色调映射（Tone Mapping）

色调映射相关选项需要特别注意：

- **不要开启 VPP 色调映射**：VPP（Video Post Processing）主要面向英特尔核显，AMD 平台开启该项可能引发转码报错或异常。如果看到 "VPP Tone Mapping" 选项，请保持关闭。
- **开启 OpenCL 色调映射**：请在界面下方找到 "Enable Tone Mapping" 或专门提及 OpenCL 的相关选项并启用。有了 OpenCL 支持，当你播放 4K HDR 视频而显示设备不支持 HDR 时，核显可利用 OpenCL 运算能力将 HDR 画面自动映射成 SDR，显著优化色彩表现，避免画面偏灰。凭借 680M 强大的计算性能，这类转码完全无压力。


---

## 7. 效果验证与监控

### A. 实时监控负载

在 Ubuntu 虚拟机中安装监控工具：

```bash
sudo apt install radeontop -y
sudo radeontop
```

打开一个 4K 视频并手动在客户端调整画质（如 4K 转 1080p，触发转码）。观察 `Graphics pipe` 和 `Video Management (VCN)` 进度条，如果有数值跳动，说明显卡正在忙碌转码。

**截图建议**：展示 `radeontop` 的输出，显示 Video 进度条在跑动，证明显卡在工作，而不是 CPU 在空转。

**为什么有些视频在 radeontop 里 Graphics pipe 始终是 0%，完全没有负载变化？**

这其实是核显直通环境下一种很常见且正常的现象，原因通常是 Jellyfin 触发了"直接播放"（Direct Play）机制。也就是说，如果你的播放设备（如浏览器、手机 App 或电视盒）原生支持该视频的编码格式（比如 H.264 或 HEVC），Jellyfin 会直接推送原始文件给客户端，不经过任何转码环节，此时 GPU 不参与处理，自然不会有负载波动。这其实是一种理想状态，因为直接播放可以最大化画质、节省服务器算力。

**如何确认当前是"直接播放"？** 在视频播放时，点击播放器右下角的"设置"（齿轮图标），选择"播放信息"（Playback Info）。如果页面中显示 "播放方法：直接播放"（Direct Play），就说明 GPU 没有参与转码，显示为 0% 是正确的。


### B. Jellyfin 仪表盘验证

1. 播放一个视频
2. 在播放界面，点击 "播放信息" 或 "Stats for Nerds"
3. 查看转码信息，如果看到 **"Transcode (Hardware)"** 字样，恭喜你，硬解配置成功！

**截图建议**：展示 Jellyfin 播放信息，显示 "Transcode (Hardware)" 字样。

### C. 日志验证

```bash
docker logs jellyfin | grep -i vaapi
# 应该看到硬件解码相关的日志
```

---

## 8. 常见问题排查

### 1. 宿主机崩溃（Kernel Panic）

**原因**：IOMMU 分组不独立，核显与硬盘控制器绑定在一起。

**解决方案**：
- 确认已添加 `pcie_acs_override=downstream,multifunction` 参数
- 确认已添加 `pci=nommconf` 参数
- 检查 GRUB 配置是否正确应用：`cat /proc/cmdline`

### 2. 虚拟机无法启动或黑屏

**检查点**：
- 确认虚拟机 BIOS 设置为 `OVMF (UEFI)`
- 确认虚拟机 Machine 设置为 `q35`
- 确认 Display 设置为 `none`

### 3. 找不到 /dev/dri/renderD128

**检查点**：
- 确认 Ubuntu 中可以看到设备：`ls -l /dev/dri/`
- 确认已安装 `linux-firmware` 和 `linux-modules-extra`
- 确认驱动已加载：`lspci -k -d 1002:` 应该显示 `amdgpu`

### 4. Docker 容器无法访问设备

**解决方案**：
```bash
# 检查设备权限
ls -l /dev/dri/

# 确认 render 组 GID
getent group render

# 确认 docker-compose.yml 中的 group_add 配置正确
```

### 5. 硬件解码不工作

**检查点**：
- 确认 Jellyfin 后台已选择 `VAAPI` 硬件加速
- 确认 VAAPI 设备路径正确：`/dev/dri/renderD128`
- 检查 Jellyfin 日志：`docker logs jellyfin`
- 确认视频格式在支持的编码器列表中

---

## 9. 性能优化建议

### A. 调整转码设置

在 Jellyfin 中：
- 降低转码质量（如果网络允许，直接播放原始文件）
- 启用转码缓存
- 限制并发转码数量

### B. 系统优化

```bash
# 设置 CPU 性能模式
sudo apt install cpufrequtils -y
sudo cpufreq-set -g performance

# 调整 swappiness（减少交换）
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### C. 网络优化

如果媒体文件在 NAS 上，确保网络带宽充足（建议千兆网络）。

---

## 10. 总结

实现 AMD 核显直通的关键点在于：

1. **PVE 层面**：必须通过 `pcie_acs_override` 彻底拆分 IOMMU 分组，并使用 `pci=nommconf` 保持系统稳定
2. **虚拟机层面**：固件补全（`linux-firmware`）和 UEFI 引导缺一不可
3. **权限层面**：Docker 的 `group_add` 映射是解决"转码失败"报错的良药

这套方案不仅能支撑全家人的影音需求，还能保持极低的待机功耗。通过硬件解码，一台低功耗的迷你主机也能流畅处理多路 4K 转码任务。

在下一篇文章中，我们将离开影音室，进入智能家居的世界 —— **HomeLab 搭建指南 (五)：智能家居中枢 Home Assistant 部署实践**。

---

## 参考资源

- [Jellyfin 官方文档](https://jellyfin.org/docs/)
- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Nyanmisaka Jellyfin 镜像说明](https://github.com/nyanmisaka/jellyfin)
- [AMD Radeon 驱动文档](https://www.amd.com/en/support/kb/faq/gpu-131)
