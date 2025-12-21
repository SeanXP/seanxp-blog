---
title: HomeLab 搭建指南 (二)：虚拟化基石 —— Proxmox VE (PVE) 系统安装与初始化
date: 2025-12-20T09:00:00+08:00
tags:
  - HomeLab
  - Proxmox
  - 虚拟化
  - Linux
categories:
  - 科技数码
draft: true
---

Proxmox VE（PVE）是 HomeLab 的核心组件，作为虚拟化平台承载着所有服务。本文基于最新的 **PVE 9.1**（Debian 13 Trixie），从零开始详细讲解安装流程、存储规划、系统优化等关键环节，帮助你构建稳定高效的虚拟化环境。

<!--more-->

> 📌 **版本说明**：本文基于 **Proxmox VE 9.1** (2025年11月19日)，底层系统为 **Debian 13.2 (Trixie)**。相比旧版本（PVE 8.x / Debian 12），主要改进包括更新的内核版本、更好的硬件支持、新版 Ceph 集成等。

## 什么是 Proxmox VE？

**Proxmox Virtual Environment（简称 PVE）** 是一个开源的企业级虚拟化管理平台，基于 Debian Linux 构建，整合了强大的虚拟化和容器技术。简单来说，**PVE = Debian + 虚拟化管理工具**。

### 核心特性

- **双虚拟化技术**：集成 KVM（硬件全虚拟化）和 LXC（轻量级容器），支持虚拟机和容器混合部署
- **友好的管理界面**：提供 Web 管理界面、命令行工具和 REST API，操作简单直观
- **企业级功能**：支持实时迁移、高可用集群、自动备份恢复等特性
- **灵活的存储选项**：支持 LVM、ZFS、NFS、Ceph 等多种存储方案
- **硬件直通支持**：可将 GPU、网卡等硬件直接分配给虚拟机使用
- **完全免费开源**：无需许可费用，适合家庭实验室和中小企业

### 为什么选择 PVE？

相比 VMware ESXi 等商业方案，PVE 最大的优势是**免费开源**且功能完整。对于 HomeLab 场景，PVE 的硬件直通能力尤其重要——可以将核显、独显等设备直通给虚拟机，实现高性能的媒体转码或图形加速。

### PVE 9.1 新特性亮点

**Proxmox VE 9.1** 基于 Debian 13 (Trixie)，带来了诸多改进：

- **Linux 6.8 内核**：更好的硬件支持，特别是新款 Intel/AMD 处理器和 GPU
- **Ceph Squid 19.2**：新一代分布式存储支持（适合多节点集群）
- **优化的 Web 界面**：响应速度提升，操作更流畅
- **改进的备份性能**：增量备份速度更快，压缩比更高
- **更好的 SDN 支持**：软件定义网络功能增强
- **QEMU 9.0**：虚拟机性能优化，支持更多虚拟硬件

## 准备工作

### 下载系统镜像

访问 [Proxmox VE 官方下载页面](https://www.proxmox.com/en/downloads) 下载最新版本的 ISO 镜像文件。

### 制作安装 U 盘

根据你的操作系统选择合适的工具：

| 操作系统 | 推荐工具 | 说明 |
|---------|---------|------|
| **Windows** | [Rufus](https://rufus.ie/) | 简单易用，速度快 |
| **macOS / Linux** | [Balena Etcher](https://www.balena.io/etcher/) | 跨平台，界面友好 |
| **Linux 命令行** | `dd` 命令 | 适合熟悉 Linux 的用户 |

**Linux dd 命令示例：**
```bash
dd if=proxmox-ve.iso of=/dev/sdX bs=1M status=progress
```
> ⚠️ 注意：使用 dd 命令前务必确认目标设备，错误的设备会导致数据丢失！

### BIOS/UEFI 配置

插入 U 盘后，重启电脑进入 BIOS/UEFI 设置界面，需要调整以下两项配置：

**1. 启用虚拟化支持**
- **Intel 处理器**：找到 `Intel VT-x` 或 `Intel Virtualization Technology`，设置为 `Enabled`
- **AMD 处理器**：找到 `AMD-V` 或 `SVM Mode`，设置为 `Enabled`

> 💡 **提示**：大部分现代主机（如迷你主机、NUC 等）默认已开启虚拟化，可在系统信息中确认后跳过此步。

**2. 调整启动顺序**
- 将 USB 设备设置为第一启动项
- 保存设置并重启（通常按 F10 保存）

## 系统安装流程

### 启动安装程序

从 U 盘成功引导后，选择第一项 `Install Proxmox VE` 进入图形化安装向导。

### 磁盘分区配置（重要！）

这是整个安装过程最关键的一步，决定了后期存储架构的灵活性。

#### 为什么不能使用默认配置？

PVE 默认的磁盘分区方案存在以下问题：

1. **local 分区太小**：默认只有 100GB，如果需要存储 ISO 镜像、备份文件等，很快就会用完
2. **local-lvm 类型限制**：LVM-Thin 类型只能存放虚拟机磁盘，无法存放 ISO 文件和备份
3. **难以调整**：安装后再想调整分区，需要删除 LVM 重建，如果已有虚拟机会非常麻烦

#### 推荐的分区方案

以 1TB 硬盘为例，建议按以下方式规划：

| 分区 | 大小 | 用途 | 后续创建方式 |
|------|------|------|-------------|
| **local** | 100GB | 系统、ISO 镜像、模板 | 安装时自动创建 |
| **local-backup** | 500GB | 备份文件、快照 | 安装后手动创建 |
| **local-lvm** | ~400GB | 虚拟机磁盘 | 安装后手动创建 |

#### 高级分区参数设置

在磁盘选择界面，**不要直接点击 Next**，而是点击 `Options` 按钮，进行如下配置：

```text
hdsize: 1024           # 硬盘总容量（GB），留空则使用全部空间
maxroot: 100           # local 分区大小：存放系统、ISO 镜像和模板
swapsize: 8            # 交换分区：建议 8GB（内存小于 32GB）或 16GB
maxvz: 0               # 关键！设为 0 阻止自动创建 local-lvm
minfree: 550           # 预留空间：500GB 用于备份 + 50GB 缓冲区
```

**参数详解：**

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `hdsize` | 使用的磁盘总容量（GB） | 留空或填写磁盘实际大小 |
| `maxroot` | local 分区大小，存放系统和 ISO | 100 GB |
| `swapsize` | 交换分区大小 | 8-16 GB |
| `maxvz` | **重点！** 设为 0 阻止自动创建 local-lvm | 0 |
| `minfree` | 预留空间，用于后续手动分配 | 550 GB（根据需求调整） |

> ⚠️ **重要说明**：
> - `maxvz: 0` 是核心设置，它阻止安装程序自动创建 local-lvm，让我们后续手动规划存储布局
> - `minfree` 预留的空间在安装后是"未分配"状态，方便手动创建备份和虚拟机存储
> - 安装过程会**格式化整个目标磁盘**，请务必确认磁盘上没有重要数据！

### 网络配置

配置静态 IP 地址，便于后续访问管理界面：

| 配置项 | 说明 | 示例值 |
|--------|------|--------|
| **Hostname** | 主机名（FQDN 格式） | `pve.local` 或 `pve.homelab.local` |
| **IP Address** | 静态 IP 地址 | `192.168.1.100` |
| **Netmask** | 子网掩码 | `255.255.255.0` （或 `/24`） |
| **Gateway** | 网关地址 | `192.168.1.1` |
| **DNS Server** | DNS 服务器 | `192.168.1.1` 或 `8.8.8.8` |

> 💡 **配置建议**：
> - 强烈建议使用静态 IP，避免 DHCP 导致 IP 变化
> - IP 地址选择你的局域网中未被占用的地址
> - 网关通常是路由器的 IP 地址

### 设置管理员密码

设置 `root` 用户密码，这个密码用于：
- SSH 远程登录
- Web 管理界面登录
- 命令行操作

> ⚠️ 请务必使用强密码并妥善保管！

### 完成安装

安装完成后，系统会显示 Web 管理界面的访问地址：

```
https://<your-pve-ip>:8006
```

> 📌 **访问地址格式**：`https://` + PVE 的 IP 地址 + `:8006` 端口  
> 例如：如果你配置的 IP 是 `192.168.1.100`，则访问地址为 `https://192.168.1.100:8006`

移除 U 盘，重启进入 PVE 系统。

## 首次登录与验证

### 访问 Web 管理界面

打开浏览器，访问安装完成时显示的地址（使用你配置的 PVE IP 地址）：

```
https://<your-pve-ip>:8006
```

> ⚠️ **证书警告**：浏览器会提示"您的连接不是私密连接"或"证书错误"，这是正常现象。PVE 使用自签名证书，点击"高级"→"继续访问"即可。

**登录信息：**
- **用户名**：`root`
- **密码**：安装时设置的 root 密码
- **Realm**：选择 `Linux PAM standard authentication`

### 关闭订阅提示（可选）

登录后会看到"No valid subscription"（无有效订阅）的提示窗口，这是正常现象。

> 💡 **关于订阅**：
> - PVE 本身**完全免费开源**，所有功能都可以正常使用
> - 订阅服务仅提供企业级技术支持和测试过的稳定版软件源
> - 家庭用户使用社区版（pve-no-subscription）完全足够
> - 如有需要，可在后续章节中了解如何关闭此提示

## 存储规划与配置

安装完成后，我们需要将预留的空间分配给备份存储和虚拟机存储。在操作前，先了解一下 PVE 的存储类型选择。

### 存储类型对比：LVM-Thin vs ZFS

PVE 支持多种存储后端，对于单硬盘家庭环境，主要需要在 **LVM-Thin** 和 **ZFS** 之间做出选择。

| 特性 | LVM-Thin（推荐） | ZFS |
|------|-----------------|-----|
| **性能开销** | 极低，几乎无额外负担 | 高，默认占用 50% 内存作为缓存 (ARC) |
| **硬件要求** | 对 SSD 友好，不挑硬件 | 需要大内存，对消费级 SSD 写入寿命消耗大 |
| **核心功能** | 支持快照、精简置备 | 支持快照、数据自愈、压缩、RAID |
| **复杂程度** | 简单，内核原生支持 | 复杂，独立文件系统，维护成本高 |
| **写入放大** | 极低 | 高（COW 机制导致大量元数据写入） |
| **适用场景** | 单盘环境、注重性能 | 多盘 RAID、数据保护要求极高 |

#### 为什么推荐 LVM-Thin？

**1. 性能优秀**  
LVM-Thin 提供接近原生块设备的性能，在单块 NVMe 硬盘上没有 ZFS 的 COW（写时复制）带来的 IO 延迟波动，特别适合运行 Windows 虚拟机。

**2. 内存友好**  
ZFS 为保证性能需要大量内存作为缓存。对于 32GB 或 64GB 内存的迷你主机，LVM-Thin 不会"抢占"宝贵的内存资源。

**3. 保护 SSD 寿命**  
ZFS 的写放大现象会大幅增加 SSD 写入量，缩短消费级 SSD 的使用寿命。LVM-Thin 的写入量要小得多。

**4. 精简置备**  
LVM-Thin 支持"用多少占多少"。虚拟机分配 100GB 虚拟磁盘，但实际只用了 10GB，物理存储也只占用 10GB。

#### 什么时候选择 ZFS？

仅在以下场景才建议使用 ZFS：

- **多盘 RAID**：有 2 块以上硬盘，需要做 RAID 1/10/Z1 等冗余
- **数据保护**：需要 ZFS 的校验和机制防止数据位翻转（Bitrot）
- **大规模压缩**：存储大量高压缩比数据（如文本日志）

### 存储池实际配置

安装完成后，我们需要手动配置之前预留的空间。在 Web 界面点击 PVE 节点名称，选择 `Shell` 打开命令行终端。

#### 1. 创建备份存储（Directory 类型）

**命令行操作：**

```bash
# 1. 创建 500GB 的逻辑卷
lvcreate -L 500G -n backup_space pve

# 2. 格式化为 ext4 文件系统
mkfs.ext4 /dev/pve/backup_space

# 3. 创建挂载点目录
mkdir -p /mnt/pve/local-backup

# 4. 添加到 fstab 实现开机自动挂载
echo "/dev/pve/backup_space /mnt/pve/local-backup ext4 defaults 0 2" >> /etc/fstab

# 5. 立即挂载所有 fstab 中的文件系统
mount -a

# 6. 验证挂载是否成功
df -h | grep local-backup
```

**在 Web 界面添加存储：**

1. 点击左侧 `数据中心` → `存储` → `添加` → `目录`
2. 填写配置：
   - **ID**：`local-backup`
   - **目录**：`/mnt/pve/local-backup`
   - **内容**：勾选 `VZDump 备份文件` 和 `片段`
3. 点击 `添加` 按钮完成

> 💡 **说明**：Directory 类型存储使用普通文件系统（ext4），可以存放备份文件、ISO 镜像等各类文件。

#### 2. 创建虚拟机存储（LVM-Thin 类型）

**命令行操作：**

```bash
# 1. 将剩余所有空间创建为 LVM Thin Pool
lvcreate -l 100%FREE --thinpool data pve

# 2. 验证创建成功
lvs

# 输出示例：
# LV            VG  Attr       LSize   Pool Origin Data%  Meta%
# backup_space  pve -wi-ao---- 500.00g
# data          pve twi-a-tz-- 400.00g             0.00   0.50
# root          pve -wi-ao---- 100.00g
# swap          pve -wi-ao----   8.00g
```

**在 Web 界面添加存储：**

1. 点击左侧 `数据中心` → `存储` → `添加` → `LVM-Thin`
2. 填写配置：
   - **ID**：`local-lvm`
   - **卷组**：选择 `pve`
   - **Thin Pool**：选择 `data`
   - **内容**：勾选 `磁盘映像` 和 `容器`
3. 点击 `添加` 按钮完成

> 💡 **说明**：LVM-Thin 提供块设备存储，专门用于虚拟机磁盘和容器，支持快照和精简置备功能。

### 最终存储架构

配置完成后，你的 PVE 存储架构如下：

| 存储名称 | 类型 | 大小 | 用途 | 支持内容 |
|---------|------|------|------|---------|
| **local** | Directory | ~100GB | 系统、ISO、模板 | ISO 映像、容器模板 |
| **local-backup** | Directory (Ext4) | 500GB | 备份、快照 | 备份文件、片段 |
| **local-lvm** | LVM-Thin | ~400GB | 虚拟机磁盘 | 磁盘映像、容器 |

在 Web 界面的 `数据中心` → `存储` 页面可以看到所有存储的状态和使用情况。

## 系统优化配置

### 软件源配置

默认情况下，PVE 会尝试访问企业版仓库，由于没有订阅会导致 `401 Unauthorized` 错误。此外，国内用户访问官方源速度较慢，建议更换为国内镜像源。

> 💡 **版本说明**：PVE 9.1 基于 **Debian 13 (Trixie)**，配置文件使用 `.sources` 后缀的 **DEB822 格式**（旧版本 PVE 8.x 基于 Debian 12 Bookworm）。

#### 1. 更换 Debian 基础源

```bash
# 备份原始配置
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 使用清华大学镜像源（Debian 13 Trixie）
cat > /etc/apt/sources.list << 'EOF'
deb https://mirrors.ustc.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb-src https://mirrors.ustc.edu.cn/debian/ trixie main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb-src https://mirrors.ustc.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
deb-src https://mirrors.ustc.edu.cn/debian-security trixie-security main contrib non-free non-free-firmware
EOF
```

#### 2. 禁用企业版软件源

```bash
# 禁用 PVE 企业版源
sed -i 's/^Enabled: yes/Enabled: no/' /etc/apt/sources.list.d/pve-enterprise.sources

# 禁用 Ceph 企业版源（如果存在）
if [ -f /etc/apt/sources.list.d/ceph.sources ]; then
    sed -i 's/^Enabled: yes/Enabled: no/' /etc/apt/sources.list.d/ceph.sources
fi
```

或者手动编辑文件，在末尾添加或修改为 `Enabled: no`：

```bash
nano /etc/apt/sources.list.d/pve-enterprise.sources
```

#### 3. 添加社区版（无订阅）软件源

```bash
cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/pve-archive-keyring.gpg

Types: deb
URIs: https://mirrors.ustc.edu.cn/proxmox/debian
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/pve-archive-keyring.gpg
EOF
```

> 📝 **版本对应关系**：
> - PVE 9.x → Debian 13 (Trixie) → Ceph Squid
> - PVE 8.x → Debian 12 (Bookworm) → Ceph Quincy

#### 4. 更新软件包

```bash
# 更新软件包列表
apt update

# 升级所有软件包
apt dist-upgrade -y

# 清理不需要的软件包
apt autoremove -y
apt autoclean
```

## 系统验证与检查

完成所有配置后，建议进行以下检查，确保系统正常运行。

### 检查存储状态

**在 Web 界面检查：**
- 点击 `数据中心` → `存储`
- 确认三个存储池（`local`、`local-backup`、`local-lvm`）都显示为 `Active` 状态
- 查看每个存储的总容量和使用情况

**在 Shell 中检查：**

```bash
# 查看 PVE 存储状态
pvesm status

# 输出示例：
# Name             Type     Status           Total            Used       Available        %
# local            dir      active       102975744         3614464        94092928    3.51%
# local-backup     dir      active       524288000           32768       524255232    0.01%
# local-lvm     lvmthin      active       419430400               0       419430400    0.00%

# 查看逻辑卷详情
lvs

# 查看文件系统挂载情况
df -h

# 查看卷组信息
vgs
```

### 检查网络连接

```bash
# 测试外网连通性
ping -c 4 www.baidu.com

# 查看网络接口配置
ip addr show

# 查看网络配置文件
cat /etc/network/interfaces

# 测试 DNS 解析
nslookup www.proxmox.com
```

### 检查系统信息

**在 Web 界面：**
- 点击节点名称，可以看到 CPU、内存、磁盘、网络等资源使用情况的实时图表
- 查看 `Summary` 页面了解系统整体状态

**在 Shell 中：**

```bash
# 查看 PVE 版本信息
pveversion -v

# 输出示例：
#proxmox-ve: 9.1.0 (running kernel: 6.17.2-1-pve)
#pve-manager: 9.1.1 (running version: 9.1.1/42db4a6cf33dac83)

# 查看 CPU 信息
lscpu | grep "Model name"
# Model name:                              AMD Ryzen 9 6900HX with Radeon Graphics

# 查看内存使用
free -h

# 查看虚拟化支持
egrep -c '(vmx|svm)' /proc/cpuinfo
# 输出 > 0 表示虚拟化已启用
```

### 常用管理命令

```bash
# 查看虚拟机列表
qm list

# 查看容器列表
pct list

# 查看节点状态
pvesh get /nodes/localhost/status

# 查看系统日志（最近 50 条）
journalctl -n 50

# 查看 PVE 服务状态
systemctl status pveproxy
systemctl status pvedaemon
systemctl status pvestatd

# 重启 PVE Web 服务（如果界面异常）
systemctl restart pveproxy
```

> 💡 **建议**：将这些命令保存到笔记中，日常维护时可能会用到。

## 下一步计划

至此，Proxmox VE 虚拟化平台已经安装并配置完成，具备以下能力：

✅ 强大的虚拟化管理平台  
✅ 合理的存储架构（系统、备份、虚拟机分离）  
✅ 优化的软件源配置  
✅ 稳定的网络连接  

**接下来可以做什么？**

1. **部署 OpenWrt 软路由**（下一篇文章主题）  
   构建 HomeLab 的网络中枢，实现科学上网、去广告、流量监控等功能

2. **创建第一个虚拟机**  
   安装 Ubuntu Server、Windows 等系统，部署各类服务

3. **配置硬件直通**  
   将核显或独显直通给虚拟机，搭建媒体服务器（Jellyfin、Plex）

4. **搭建容器服务**  
   使用 LXC 容器部署轻量级服务，如 Home Assistant、Nginx 等

## 总结

本文基于 **Proxmox VE 9.1**（Debian 13 Trixie）详细介绍了完整的安装与配置流程，核心要点包括：

### 关键配置回顾

✅ **磁盘分区规划**  
避开默认配置陷阱，通过 `maxvz: 0` 和 `minfree` 参数预留空间，实现系统、备份、虚拟机的合理分离

✅ **存储架构设计**  
对比 LVM-Thin 和 ZFS 的特性，为单盘家庭环境选择性能更优的 LVM-Thin 方案

✅ **软件源优化**  
配置 Debian 13 和 Ceph Squid 的国内镜像源，解决企业版订阅报错，加速系统更新

✅ **系统验证**  
通过命令行和 Web 界面多维度验证存储、网络、服务状态

### 下一步建议

PVE 作为 HomeLab 的虚拟化基石，其稳定性至关重要。在正式部署服务前，建议：

1. **熟悉 Web 界面**：了解虚拟机、存储、网络的管理操作
2. **备份配置**：定期备份 PVE 配置文件（`/etc/pve/`）
3. **测试快照功能**：创建测试虚拟机，体验快照和恢复流程
4. **监控资源使用**：观察 CPU、内存、磁盘 IO 的正常水平

在下一篇文章中，我们将在 PVE 上部署 **OpenWrt 软路由**，构建 HomeLab 的网络中枢，实现科学上网、去广告、流量监控等功能。

## 参考资源

### 官方文档

- [Proxmox VE 官方文档](https://pve.proxmox.com/pve-docs/) - 权威的技术参考手册
- [Proxmox VE Wiki](https://pve.proxmox.com/wiki/Main_Page) - 社区维护的知识库
- [Proxmox VE 论坛](https://forum.proxmox.com/) - 官方技术支持论坛
- [Proxmox VE 9.1 发行说明](https://pve.proxmox.com/wiki/Roadmap#Proxmox_VE_9.1) - 新版本特性

### 软件源镜像

- [清华大学开源镜像站](https://mirrors.tuna.tsinghua.edu.cn/help/debian/) - Debian 换源指南
- [中科大镜像站](https://mirrors.ustc.edu.cn/) - 速度快，稳定性好
- [阿里云镜像站](https://developer.aliyun.com/mirror/) - 国内访问快速

### 技术文档

- [LVM 管理指南](https://wiki.debian.org/LVM) - Linux LVM 详细文档
- [Debian 13 (Trixie) 发行说明](https://www.debian.org/releases/trixie/) - 底层系统文档
- [QEMU/KVM 文档](https://www.linux-kvm.org/page/Documents) - 虚拟化技术原理

---

### 系列文章导航

📖 **HomeLab 搭建指南系列：**

- [上一篇：HomeLab 搭建指南 (一)：硬件选型与规划](/homelab-01-intro-and-hardware-selection/)
- **本篇：HomeLab 搭建指南 (二)：Proxmox VE 安装与配置**
- [下一篇：HomeLab 搭建指南 (三)：OpenWrt 软路由安装与配置](/homelab-03-openwrt-installation-and-network-configuration/)

