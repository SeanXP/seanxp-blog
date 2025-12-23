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
在 HomeLab 环境中搭建媒体服务器是许多玩家的核心需求。通过硬件视频解码（Hardware Transcoding），我们可以将繁重的视频转码任务从 CPU 转移到 GPU，从而大幅降低系统负载，即便是低功耗的迷你主机也能轻松应对多路 4K 电影的实时转码。

本文将以 **PVE 9.1** 为宿主机，**AMD 680M** 核显为例，详细记录如何实现核显的彻底隔离、直通给 Ubuntu 24.04 虚拟机，并在 Docker 环境中部署 Jellyfin，打造高效、流畅的家庭影音中心。
<!--more-->

## 1. 前言：为何选择硬件解码？

### 性能与功耗的平衡
视频转码属于计算密集型任务。若使用 CPU 进行软件解码（Soft Decoding），播放一部 4K HEVC 编码的高码率电影时，CPU 占用率往往会飙升至 100%，导致系统响应迟缓甚至崩溃。

相比之下，利用核显（iGPU）进行硬件解码（Hard Decoding），调用显卡内部专用的编解码电路（如 Intel QuickSync 或 AMD VCN），不仅处理速度更快，而且能将 CPU 占用率控制在 10% 以内，实现低功耗、高并发的转码体验。

**性能对比：**
- **CPU 软解 4K HEVC**：CPU 占用 80-100%，功耗高，并发能力弱。
- **核显硬解 4K HEVC**：CPU 占用 < 10%，功耗低，支持多路并发。

### 硬件环境
- **CPU**: AMD Ryzen 7 6800H (集成 Radeon 680M 核显，RDNA2 架构)
- **PVE 版本**: 9.1.1
- **虚拟机系统**: Ubuntu 24.04.1 LTS

---

## 2. PVE 宿主机环境准备 (核心隔离步骤)

这是最关键的一步。由于许多 AMD 迷你主机（如零刻、摩方等）的 IOMMU 分组设计较为粗糙，直接直通显卡可能会导致宿主机在虚拟机启动时发生内核崩溃（Kernel Panic）。我们需要手动调整内核参数来规避这一风险。

### A. 修改 GRUB 引导参数

编辑 `/etc/default/grub` 文件：

```bash
vi /etc/default/grub
```

找到 `GRUB_CMDLINE_LINUX_DEFAULT` 这一行，修改为如下内容：

```bash
# 原配置参考：GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt video=efifb:off initcall_blacklist=sysfb_init pcie_acs_override=downstream,multifunction pci=nommconf vfio-pci.ids=1002:1681"
```

**关键参数解析：**

- `iommu=pt`: 开启 IOMMU 透传模式，提升性能与兼容性。
- `video=efifb:off`: 禁止宿主机使用 EFI 帧缓冲，防止宿主机占用显卡导致直通失败。
- `initcall_blacklist=sysfb_init`: 阻止系统帧缓冲初始化，进一步释放显卡控制权。
- `pcie_acs_override=downstream,multifunction`: **核心参数**。强制拆分 IOMMU 分组，防止核显与 NVMe 硬盘控制器等关键设备分在同一组，避免虚拟机启动时连带宿主机硬盘掉线。
- `pci=nommconf`: **核心参数**。解决部分 AMD 平台在 PCI 总线重置时的内存映射冲突，防止死机。
- `vfio-pci.ids=1002:1681`: 指定需隔离的设备硬件 ID（此处为 680M），让宿主机启动时直接将其交由 VFIO 驱动接管。

**如何查找你的核显硬件 ID：**

```bash
lspci -nn | grep -i vga
# 输出示例：
# e5:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] [1002:1681] (rev c7)
# 其中 [1002:1681] 即为硬件 ID
```

### B. 配置驱动黑名单

为了确保 PVE 宿主机完全不加载显卡驱动，我们需要将其加入黑名单。编辑 `/etc/modprobe.d/pve-blacklist.conf`：

```bash
vi /etc/modprobe.d/pve-blacklist.conf
```

添加以下内容：

```bash
blacklist amdgpu
blacklist radeon
```

### C. 更新引导并重启

执行以下命令使配置生效：

```bash
update-grub
update-initramfs -u
reboot
```

> **重要**：`update-initramfs -u` 是必须的，否则驱动黑名单可能不会在内核加载初期生效。

### D. 验证隔离状态

重启后，通过 SSH 登录 PVE，执行以下命令检查显卡状态：

```bash
lspci -k -s e5:00.0
# 请将 e5:00.0 替换为你实际的显卡 PCI 地址
```

**预期输出：**

```text
e5:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Rembrandt [Radeon 680M] (rev c7)
	Subsystem: Advanced Micro Devices, Inc. [AMD/ATI] Device 0124
	Kernel driver in use: vfio-pci
	Kernel modules: amdgpu
```

如果看到 `Kernel driver in use: vfio-pci`，说明显卡已被 VFIO 成功接管，隔离完成。此时即便虚拟机配置不当，也不会波及宿主机的稳定性。

### E. 关于 PVE "黑屏" 的说明

**现象**：配置完成后，连接在宿主机上的显示器可能会在启动过程中定格或直接黑屏无信号。  
**解读**：这是**预期行为**。由于我们配置了 `video=efifb:off` 并隔离了显卡，宿主机不再向显示器输出图像。这恰恰证明了隔离措施已生效。后续对 PVE 的管理请完全通过 Web 界面或 SSH 进行。

---

## 3. 虚拟机创建与硬件直通 (VM Setup)

在 PVE Web 界面创建或修改 Ubuntu 虚拟机，以下配置至关重要：

### 核心配置清单

| 选项 | 推荐设置 | 简要说明 |
| :--- | :--- | :--- |
| **Start at boot** | `No` | 调试阶段建议关闭，防止直通失败导致宿主机死循环。 |
| **Machine** | `q35` | 支持 PCIe 直通的现代总线架构。 |
| **BIOS** | `OVMF (UEFI)` | 新显卡（680M等）必须使用 UEFI 引导。 |
| **Display** | `none` | **关键**。避免虚拟显卡与直通卡冲突。 |
| **CPU** | `host` / 1 Socket | 透传 CPU 特性；Socket 设为 1 匹配移动端架构。|
| **Memory** | `Balloon: No` | PCI 直通必须锁定内存，**不可开启**动态分配。 |
| **Hard Disk** | `>= 20GB` | 建议预留充足空间，避免后期扩容麻烦。 |

**特别提醒**：
在 "Memory" -> "Advanced" 中，务必确保 **Ballooning Device** 未勾选。PCI 直通场景下，内存必须为静态分配，否则会影响 IOMMU 映射，导致显卡驱动加载失败或宿主机 Kernel Panic。

### 添加 PCI 设备

1. 在虚拟机 "Hardware" 选项卡点击 `Add` -> `PCI Device`。
2. 选择对应的显卡设备（如 `0000:e5:00.0`）。
3. **勾选**：
   - `ROM-Bar`: 允许虚拟机读取显卡 ROM。
   - `PCI-Express`: 使用 PCIe 总线协议。
4. **不勾选**：
   - `Primary GPU`: 建议不勾选，仅将其作为计算/渲染卡使用，稳定性更好。
   - `All Functions`: 不勾选，避免引入不必要的音频或其他子设备干扰。

---

## 4. Ubuntu 虚拟机驱动配置

进入 Ubuntu 24.04 虚拟机，我们需要确认显卡已被正确识别。

### A. 检查显卡状态

依次执行以下命令进行诊断：

```bash
# 1. 检查渲染设备节点
ls -l /dev/dri
# 预期：应看到 card0 和 renderD128 (或类似编号)

# 2. 检查 PCI 设备识别情况
lspci -nn | grep -i vga
# 预期：显示 Radeon 680M [1002:1681]

# 3. 检查内核驱动加载情况
lspci -k -d 1002:
# 预期：Kernel driver in use: amdgpu
```

**情况分析**：
- 如果 `/dev/dri` 下存在 `renderD128`，且驱动为 `amdgpu`，说明显卡已就绪，可直接跳到"权限管理"。
- 如果看不到设备，或驱动未加载，请执行下方的"更新驱动与固件"。

### B. 更新驱动与固件 (如果未识别)

Ubuntu 24.04 默认可能缺少部分 RDNA2 架构的固件。

```bash
sudo apt update
sudo apt install linux-firmware linux-modules-extra-$(uname -r) -y
sudo update-initramfs -u
sudo reboot
```

### C. 配置权限

Docker 容器默认没有访问硬件设备的权限。我们需要获取 `render` 用户组的 ID，并在 Docker 中进行映射。

```bash
getent group render | cut -d: -f3
# 输出示例：993 (请记录此数字)
```

**原理解析**：`/dev/dri/renderD128` 设备通常属于 `render` 用户组。容器内的用户若想使用该设备，必须拥有对应的组权限。

---

## 5. Docker 与 Jellyfin 部署

推荐使用 `nyanmisaka/jellyfin` 镜像，该版本针对国内环境和硬件转码进行了大量优化。

### A. Docker 环境准备

```bash
# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### B. 编写 docker-compose.yml

```yaml
services:
  jellyfin:
    image: nyanmisaka/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    # 网络模式：host 模式性能最好，但 bridge 模式端口管理更灵活，这里使用 bridge
    ports:
      - 8096:8096
      - 8920:8920
      - 7359:7359/udp # 服务发现
      - 1900:1900/udp # DLNA
    volumes:
      - /srv/jellyfin/config:/config
      - /srv/jellyfin/cache:/cache
      - /path/to/your/media:/media:ro # 媒体库路径
    devices:
      - /dev/dri:/dev/dri # 显卡直通核心配置
    group_add:
      - "993" # 这里填写上一步获取的 render 组 ID
    environment:
      - TZ=Asia/Shanghai
      - PUID=1000 # 建议填写当前用户的 UID
      - PGID=1000 # 建议填写当前用户的 GID
```

启动服务：

```bash
docker compose up -d
```

---

## 6. Jellyfin 硬件解码深度配置

访问 `http://IP:8096` 完成初始化后，进入 `控制台` -> `播放` 进行核心设置。

### A. 开启硬件加速

- **硬件加速**: 选择 `Video Acceleration API (VAAPI)`。
  *(注：AMD 显卡在 Linux 下通常使用 VAAPI，NVIDIA 使用 NVENC，Intel 使用 QSV)*
- **VAAPI 设备**: 保持默认 `/dev/dri/renderD128`。

### B. 解码与编码选项

- **启用硬件解码**: 将列表中的 H264, HEVC, VP9, AV1 等全部勾选。680M 性能强大，支持全格式硬解。
- **启用硬件编码**: 建议勾选 "启用 HEVC 编码" 和 "启用 AV1 编码" (如果终端支持)。

### C. 兼容性避坑指南 (重要)

**问题**：为什么开启了 AV1 硬编，浏览器播放却报错？

**原因**：虽然 680M 支持 AV1 硬件编码，但目前大多数浏览器和老旧设备对实时转码后的 AV1 流兼容性极差，极易导致“客户端不支持该媒体”的报错。相比之下，**HEVC (H.265) 在现代环境下体验已显著提升**（例如在 macOS 端的 Chrome/Safari 浏览器上体验非常优秀）。

**策略建议**：
1. **追求极致兼容**：如果你的设备非常杂乱，建议只勾选 **H.264** 编码，这是“万能药”。
2. **平衡画质与带宽**：强烈建议开启 **HEVC 硬件编码**。目前 macOS 端浏览器及绝大多数移动 App 均能完美支持，能以更小的带宽换取更高的画质。
3. **AV1 慎用**：除非你确定所有播放终端（如最新的安卓盒子、高端手机）均能解码 AV1，否则**建议关闭 AV1 编码选项**，避免播放失败。

### D. 色调映射 (HDR 转 SDR)

播放 HDR 电影时，如果显示器不支持 HDR，画面会发灰。
- **VPP 色调映射**: **关闭** (可选，这是 Intel 的技术，我的小主机是 AMD CPU，因此需要关闭)。
- **色调映射 (Tone Mapping)**: **开启**。利用 OpenCL 进行色彩空间转换，680M 处理此类任务游刃有余。

---

## 7. 效果验证

### 验证方法 1: 实时监控

在 Ubuntu 虚拟机中安装 `radeontop`：

```bash
sudo apt install radeontop -y
sudo radeontop
```

播放一个 4K 视频并手动选择低码率（触发转码），观察 `Graphics pipe` 和 `VCN` 的数值。如有波动，说明显卡正在工作。

### 验证方法 2: 播放信息

在 Jellyfin 播放界面点击 "播放信息"，查看 "转码" 一栏。如果显示 **"Transcode (Hardware)"**，即代表配置成功。

> **提示**：如果显示 **"Direct Play" (直接播放)**，说明客户端直接支持该格式，无需转码，显卡不参与工作，这是最高效的状态。

---

## 8. 常见故障排查

1. **宿主机死机/重启**：
   - 检查 GRUB 参数是否包含 `pci=nommconf` 和 `pcie_acs_override`。
   - 检查虚拟机内存是否关闭了 Ballooning。

2. **Jellyfin 报错 "Playback Error"**：
   - 检查 Docker `group_add` 是否正确填写了 `render` 组 ID。
   - 检查是否开启了浏览器不支持的 HEVC 编码。

3. **找不到 `/dev/dri`**：
   - 确认 PVE 是否成功将显卡隔离（lspci 显示 vfio-pci）。
   - 确认虚拟机内核版本是否过低（建议 Ubuntu 22.04+）。

---

## 9. 总结

通过 PVE 的参数调优和 Docker 的权限映射，我们成功释放了 AMD 680M 核显的潜能。这套方案不仅让家庭影院系统具备了强大的 4K 转码能力，更保持了 HomeLab 的低功耗与高稳定性。

在下一篇 **[HomeLab 搭建指南 (五)]** 中，我们将探讨如何部署 **Home Assistant**，将家中的智能设备接入这个强大的控制中心。