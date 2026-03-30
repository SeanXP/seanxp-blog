---
title: HomeLab 搭建指南 (五)：智慧生活 —— HomeAssistant 部署与设备接入入门
date: 2025-12-20T12:00:00+08:00
tags:
  - HomeLab
  - HomeAssistant
  - 智能家居
  - 物联网
categories:
  - 科技数码
draft: true
---
HomeAssistant（HA）是一个开源的智能家居自动化平台，可以将各种智能设备统一管理，实现跨品牌、跨协议的设备联动。本文将介绍如何在 PVE 上部署 HomeAssistant OS（HAOS），并接入第一个智能设备。
<!--more-->

## 什么是 HomeAssistant？

HomeAssistant 是一个基于 Python 的智能家居自动化平台，具有以下特点：

1. **开源免费**：完全开源，社区活跃
2. **设备兼容性强**：支持 2000+ 种设备和服务
3. **本地运行**：数据存储在本地，保护隐私
4. **高度可定制**：支持丰富的插件和自动化
5. **跨平台**：支持多种安装方式（Docker、虚拟机、直接安装等）

HomeAssistant 可以：
- 统一管理不同品牌的智能设备
- 创建复杂的自动化场景
- 提供统一的控制界面
- 支持语音助手集成（Google Assistant、Alexa 等）
- 实现设备间的联动和条件触发

## 安装方式选择

HomeAssistant 有多种安装方式：

### 1. Home Assistant OS (HAOS) - 推荐

**优点：**
- 官方推荐，最稳定
- 包含 Supervisor，方便管理插件
- 支持自动更新
- 适合长期使用

**缺点：**
- 需要独立虚拟机或物理机
- 资源占用相对较大

**适用场景：**
- 作为主要智能家居平台
- 需要稳定可靠的运行环境

### 2. Home Assistant Container (Docker)

**优点：**
- 资源占用小
- 可以与其他服务共享主机
- 配置灵活

**缺点：**
- 需要手动管理更新
- 不支持 Supervisor（部分插件无法使用）

**适用场景：**
- 已有 Docker 环境
- 资源有限的情况

### 3. Home Assistant Core (Python)

**优点：**
- 最轻量
- 完全控制

**缺点：**
- 需要手动配置 Python 环境
- 更新和维护复杂

**适用场景：**
- 高级用户
- 特殊需求场景

本文选择 **HAOS** 方式，因为它最稳定且功能完整。

## 在 PVE 中安装 HAOS

### 1. 下载 HAOS 镜像

访问 [HomeAssistant 官网](https://www.home-assistant.io/installation/) 下载 HAOS 镜像。

选择格式：`ova`（适用于虚拟化平台）

或直接下载：
```bash
# 下载最新版本（示例，请访问官网获取最新链接）
wget https://github.com/home-assistant/operating-system/releases/download/xx.x/haos_xxx.ova
```

### 2. 转换镜像格式

PVE 需要 `.qcow2` 格式，需要转换：

```bash
# 如果下载的是 ova，先解压
tar -xf haos_xxx.ova

# 转换 vmdk 为 qcow2
qemu-img convert -f vmdk -O qcow2 haos_xxx-disk001.vmdk haos.qcow2
```

### 3. 创建虚拟机

在 PVE Web 界面：

1. **General**：
   - VM ID：选择一个 ID（如 101）
   - Name：`homeassistant`

2. **OS**：
   - 选择 "Do not use any media"

3. **System**：
   - Graphic Card：`Default`
   - Qemu Agent：取消勾选

4. **Hard Disk**：
   - 删除默认硬盘
   - 点击 "Add" → "Hard Disk" → "Import disk"
   - 选择转换好的 `haos.qcow2` 文件
   - 存储选择你的存储池
   - 大小：至少 32GB（推荐 64GB）

5. **CPU**：
   - Cores：2（推荐 4）
   - Type：`host`

6. **Memory**：
   - Memory：2GB（推荐 4GB）

7. **Network**：
   - Model：`VirtIO (paravirtualized)`
   - Bridge：`vmbr0`

### 4. 启动虚拟机

启动后，HAOS 会自动配置网络（使用 DHCP）。

### 5. 查找 IP 地址

在 PVE 主机上查看：

```bash
# 查看 ARP 表
arp -a | grep -i home

# 或查看 DHCP 租约
cat /var/lib/dhcp/dhcpd.leases | grep -i home
```

或在路由器管理界面查看新连接的设备。

### 6. 访问 HomeAssistant

打开浏览器访问：
```
http://homeassistant-ip:8123
```

首次访问会显示设置向导。

## 初始配置

### 1. 创建账户

按照向导创建管理员账户：
- 用户名
- 密码（请妥善保管）
- 名称（可选）

### 2. 设置位置

- 时区：选择你的时区
- 位置：设置家庭位置（用于天气、日出日落等功能）

### 3. 完成设置

完成向导后，进入 HomeAssistant 主界面。

## 安装 HACS（Home Assistant Community Store）

HACS 是 HomeAssistant 的第三方插件商店，提供了大量社区开发的集成和主题。

### 1. 进入开发者模式

1. 点击左下角用户名
2. 滚动到底部，启用 "Advanced Mode"
3. 启用 "Developer Mode"

### 2. 安装 HACS

1. 打开终端（Terminal & SSH 插件，如果没有则先安装）
2. 运行安装命令：

```bash
wget -O - https://get.hacs.xyz | bash -
```

3. 重启 HomeAssistant：
   - `Developer Tools` → `YAML` → 点击 "RESTART"

### 3. 配置 HACS

1. 重启后，进入 `Configuration` → `Integrations`
2. 点击 "Add Integration"
3. 搜索 "HACS"
4. 按照向导完成配置（需要 GitHub Token）

### 4. 使用 HACS

安装完成后，左侧菜单会出现 "HACS" 选项，可以：
- 浏览和安装集成（Integrations）
- 安装主题（Themes）
- 安装前端卡片（Frontend）

## 接入第一个智能设备

### 示例：接入小米智能设备

小米设备通常使用 `Xiaomi Miot Auto` 集成：

#### 1. 安装集成

通过 HACS 安装：
1. 进入 `HACS` → `Integrations`
2. 点击右下角 "+" 按钮
3. 搜索 "Xiaomi Miot Auto"
4. 点击 "Download"
5. 重启 HomeAssistant

#### 2. 配置集成

1. 进入 `Configuration` → `Integrations`
2. 点击 "Add Integration"
3. 搜索 "Xiaomi Miot Auto"
4. 按照向导登录小米账号
5. 选择要接入的设备

#### 3. 验证设备

配置完成后，设备应该出现在：
- `Overview` 页面（主界面）
- `Developer Tools` → `States`（可以查看所有设备状态）

### 示例：接入 Zigbee 设备

如果需要接入 Zigbee 设备（如 Aqara、Philips Hue 等），需要：

#### 1. 准备 Zigbee 网关

- USB Zigbee 适配器（如 CC2531、Sonoff Zigbee 3.0 USB Dongle）
- 或使用支持 Zigbee 的设备（如 Home Assistant Yellow）

#### 2. 安装 Zigbee 集成

推荐使用 `ZHA`（Zigbee Home Automation）或 `Zigbee2MQTT`：

**ZHA 方式：**
1. `Configuration` → `Integrations` → `Add Integration`
2. 搜索 "ZHA"
3. 选择 Zigbee 适配器
4. 按照向导配置

**Zigbee2MQTT 方式：**
1. 通过 HACS 安装 "Zigbee2MQTT"
2. 需要先安装 MQTT Broker（如 Mosquitto）
3. 配置 Zigbee2MQTT 连接到 MQTT
4. 在 HomeAssistant 中配置 MQTT 集成

### 示例：接入 Wi-Fi 设备

很多 Wi-Fi 智能设备支持通过 MQTT 或直接集成：

1. 查看设备是否在 [HomeAssistant 集成列表](https://www.home-assistant.io/integrations/) 中
2. 如果有，按照文档配置
3. 如果没有，可以尝试：
   - 通过 MQTT 接入
   - 使用第三方集成（HACS）
   - 自定义集成

## 基础自动化示例

### 示例 1：定时开关灯

1. 进入 `Configuration` → `Automations & Scenes`
2. 点击 "Create Automation"
3. 配置触发条件：
   - Trigger：Time
   - At：`18:00:00`（每天 18:00）
4. 配置动作：
   - Action：Call Service
   - Service：`light.turn_on`
   - Entity：选择你的灯
5. 保存

### 示例 2：传感器触发

1. 创建自动化
2. 触发条件：
   - Trigger：State
   - Entity：选择传感器（如人体传感器）
   - To：`on`（检测到有人）
3. 动作：
   - 打开灯
   - 延迟 5 分钟
   - 关闭灯

### 示例 3：日出日落自动化

1. 触发条件：
   - Trigger：Sun
   - Event：`sunset`（日落）
2. 动作：
   - 打开灯
   - 调整亮度

## 界面定制

### 1. 安装主题

通过 HACS 安装主题：
1. `HACS` → `Frontend` → `Themes`
2. 浏览并安装喜欢的主题
3. 在用户设置中选择主题

### 2. 自定义仪表盘

1. 点击右上角三个点
2. 选择 "Edit Dashboard"
3. 可以：
   - 添加卡片（Cards）
   - 调整布局
   - 创建多个仪表盘

### 3. 移动端应用

HomeAssistant 提供官方移动应用：
- iOS：App Store 搜索 "Home Assistant"
- Android：Google Play 搜索 "Home Assistant"

## 备份与恢复

### 1. 创建备份

1. `Configuration` → `System` → `Backups`
2. 点击 "Create Backup"
3. 选择要备份的内容
4. 创建备份

### 2. 恢复备份

1. 在备份列表中选择备份
2. 点击 "Restore"
3. 按照提示完成恢复

### 3. 自动备份

可以配置自动化定期创建备份，或使用 `Google Drive Backup` 等插件自动上传到云存储。

## 常见问题排查

### 1. 设备无法发现

- 检查设备是否在同一网络
- 检查防火墙设置
- 查看日志：`Configuration` → `System` → `Logs`

### 2. 集成无法安装

- 检查网络连接
- 检查 HACS 是否正常
- 查看错误日志

### 3. 自动化不工作

- 检查触发条件是否正确
- 检查设备状态
- 查看自动化日志

## 进阶功能

### 1. Node-RED 集成

Node-RED 是可视化流程编辑器，可以创建更复杂的自动化：

1. 通过 HACS 安装 "Node-RED Companion"
2. 安装 Node-RED 插件
3. 配置 Node-RED 集成

### 2. MQTT Broker

安装 Mosquitto MQTT Broker 可以接入更多设备：

1. 通过 HACS 安装 "Mosquitto broker"
2. 配置 MQTT 集成
3. 设备通过 MQTT 接入

### 3. 语音助手集成

- Google Assistant：通过 Nabu Casa 或手动配置
- Amazon Alexa：通过 Nabu Casa 或 emulated_hue
- Apple HomeKit：内置支持

## 总结

HomeAssistant 作为智能家居中枢，可以统一管理各种智能设备，实现复杂的自动化场景。关键步骤：

1. **安装 HAOS**：在 PVE 中创建虚拟机并安装
2. **初始配置**：完成账户和位置设置
3. **安装 HACS**：扩展功能
4. **接入设备**：根据设备类型选择合适的集成
5. **创建自动化**：实现智能场景

至此，HomeLab 搭建指南系列文章已经完成，涵盖了从硬件选型到各个服务的部署。希望这些内容能帮助你搭建自己的 HomeLab，享受 DIY 的乐趣！

## 参考资源

- [HomeAssistant 官方文档](https://www.home-assistant.io/docs/)
- [HACS 官网](https://hacs.xyz/)
- [HomeAssistant 社区论坛](https://community.home-assistant.io/)
- [Awesome Home Assistant](https://www.awesome-ha.com/)

