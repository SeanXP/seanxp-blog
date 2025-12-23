---
title: HomeLab 搭建指南 (二)：虚拟化基石 —— Proxmox VE 系统安装与最佳实践
date: 2025-12-20T09:00:00+08:00
tags:
  - HomeLab
  - PVE
  - Linux
categories:
  - 科技数码
draft: false
---

上一篇我们搞定了硬件，今天我们将为这台钢铁巨兽注入灵魂——安装 **Proxmox VE (PVE)** 虚拟化系统。

本文不同于通用的安装流水账，我将重点讲解 **如何避开默认分区的坑**、**如何设计科学的存储架构** 以及 **初始化系统的最佳实践**。

<!--more-->

> 📌 **环境说明**：本文演示环境为 **Proxmox VE 9.1** (基于 Debian 13 Trixie)。即使你使用的是旧版本 (8.x)，核心逻辑也是通用的。

## 一、 核心概念：为什么是 PVE？

**Proxmox VE** 本质上是一个 **Debian Linux + KVM 虚拟化内核 + Web 管理界面** 的集合体。

相比 ESXi，它对家用硬件极其友好：
*   **免费开源**：没有授权费，功能无阉割。
*   **硬件直通 (Passthrough)**：不仅能直通网卡做软路由，还能完美直通核显给 Jellyfin 做硬解。
*   **LXC 容器**：除了跑虚拟机 (VM)，还能跑极轻量的 LXC 容器（类似系统级 Docker），资源占用极低。

---

## 二、 关键准备：BIOS 设置

很多现代的迷你主机（如文中提到的 GEM12 Max 等）出厂时默认已经开启了虚拟化支持，**你可能根本不需要进入 BIOS 修改任何设置**。

但为了保险起见，建议插入 U 盘启动时快速检查两点：

1.  **开启虚拟化技术**：
    *   Intel 平台：找到 `VT-x` 和 `VT-d`。
    *   AMD 平台：找到 `SVM` 和 `IOMMU`。
    *   *确保状态为 `Enabled`。*
2.  **调整启动顺序**：
    *   确保 **USB 设备** 排在第一位，或者开机狂按 F7/F11/F12 (根据品牌不同) 调出启动菜单选择 U 盘。

> 💡 **小贴士**：只要能从 U 盘成功进入 PVE 安装界面，说明基础设置都没问题，不用过度纠结 BIOS 选项。

---

## 三、 安装避坑指南：磁盘分区 (必看！)

**这是 PVE 安装最大的坑，没有之一。**

PVE 默认的 "Next, Next" 安装策略会把大部分空间划给 `local-lvm`，导致你后续想存 ISO 镜像、备份文件时发现空间不足，非常被动。

### 推荐的分区策略

我们要在安装阶段手动干预，实现以下布局（以 1TB SSD 硬盘为例）：

1.  **系统与镜像 (local)**: 100GB。存放 PVE 系统、ISO 镜像、LXC 模板。
2.  **备份与快照 (local-backup)**: 500GB。存放虚拟机备份、快照。
3.  **虚拟机磁盘 (local-lvm)**: 剩余空间。存放 VM 和 LXC 的虚拟磁盘。

### 操作步骤

在安装界面的 **Target Harddisk** 这一步，**千万别直接点 Next**！点击 `Options`，填入以下参数：

*   **hdsize**: `(留空)` (使用整块盘)
*   **swapsize**: `8` (8GB 交换分区，内存大可设为 4)
*   **maxroot**: `100` (强制系统盘 local 只有 100GB)
*   **minfree**: `550` (关键！保留 550GB 空闲空间不分配)
*   **maxvz**: `0` (关键！禁止自动创建 local-lvm，我们稍后手动建)

> ⚠️ **解释**：`minfree` 保留的空间会在安装后变成“未分配”状态，方便我们灵活支配。

---

## 四、 存储架构实战

系统安装好并登录 Web 界面（推荐第一时间在登录框左下角切换语言为 **Chinese (Simplified)**）后，我们需要把刚才保留的 550GB 空间用起来。

进入 PVE 的 **Shell**，执行以下魔法。

### 1. 创建备份专用库 (Directory)

我们要把这部分空间格式化为 ext4 文件系统，用于存放备份文件。LVM-Thin 虽然快，但不支持直接存放文件。

```bash
# 1. 创建名为 backup_space 的逻辑卷，大小 500G
lvcreate -L 500G -n backup_space pve

# 2. 格式化为 ext4
mkfs.ext4 /dev/pve/backup_space

# 3. 创建挂载点并挂载
mkdir -p /mnt/pve/local-backup
mount /dev/pve/backup_space /mnt/pve/local-backup

# 4. 写入 fstab 实现开机自动挂载
echo "/dev/pve/backup_space /mnt/pve/local-backup ext4 defaults 0 2" >> /etc/fstab
```

**Web 界面操作**：
`数据中心` -> `存储` -> `添加` -> `目录`
*   ID: `local-backup`
*   目录: `/mnt/pve/local-backup`
*   内容: 勾选 `备份`、`导出`、`片段`

### 2. 创建虚拟机专用池 (LVM-Thin)

剩下的空间，全部划给 LVM-Thin，它是存放虚拟机磁盘的最佳选择（速度快、支持快照、不占内存）。

```bash
# 将剩余空间全部创建为 Thin Pool
lvcreate -l 100%FREE --thinpool data pve
```

**Web 界面操作**：
`数据中心` -> `存储` -> `添加` -> `LVM-Thin`
*   ID: `local-lvm`
*   卷组: `pve`
*   Thin Pool: `data`
*   内容: `磁盘映像`、`容器`

---

## 五、 系统初始化最佳实践

### 1. 更换国内源 (解决了再也不慢)

国内网络环境下，必须换源。PVE 9.1 基于 Debian 13 (Trixie)，请注意代号。

**Debian 系统源** (`/etc/apt/sources.list`):
```bash
sed -i 's/ftp.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
sed -i 's/security.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
```

**PVE 软件源** (`/etc/apt/sources.list.d/pve-no-subscription.list`):
```bash
# 移除企业源
rm -f /etc/apt/sources.list.d/pve-enterprise.list

# 添加社区源
echo "deb https://mirrors.ustc.edu.cn/proxmox/debian trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
```

### 2. 去除“无订阅”弹窗

每次登录都弹窗很烦？一键干掉它。

```bash
sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```
 参考：[Proxmox VE 9.0 日常维护，去掉未订阅的提示，和设置国内源——2025年8月6日更新 | 魔都水滴](https://blog.margrop.net/post/proxmox-ve-daily-maintain/)

---

## 六、 验证与总结

执行 `pvesm status`，你应该能看到清晰的三层存储结构：

| 存储 ID | 类型 | 用途 |
| :--- | :--- | :--- |
| **local** | dir | 存放 ISO 镜像、LXC 模板 |
| **local-backup** | dir | 存放虚拟机备份、快照 |
| **local-lvm** | lvmthin | 存放虚拟机磁盘 (VM Disk) |

至此，一个 **分区科学、存储分离、网络通畅** 的 PVE 宿主机就就绪了。

它就像一个干净整洁的毛坯房，水电煤（存储、网络）都已接通。下一篇，我们将开始硬装——**部署 OpenWrt 软路由**，接管全屋网络，让所有设备起飞。

---

### 📖 系列导航
*   [上一篇：HomeLab 搭建指南 (一)：硬件选型与规划](/homelab-01-introduction/)
*   **本篇：HomeLab 搭建指南 (二)：Proxmox VE 系统安装与最佳实践**
*   [下一篇：HomeLab 搭建指南 (三)：OpenWrt 软路由安装与配置](/homelab-03-openwrt-installation-and-network-configuration/)