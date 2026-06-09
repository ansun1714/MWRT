# Fudy WH3000 Pro —— LEDE 自定义固件编译

基于 [LEDE](https://github.com/coolsnowwolf/lede) 项目，通过 GitHub Actions 自动编译，
专为 **华硅科技 WH3000 Pro**（MT7981 / MediaTek Filogic）定制的 OpenWrt 固件。

[

![Build LEDE](../../actions/workflows/build-lede.yml/badge.svg)

](../../actions/workflows/build-lede.yml)
[

![Build IPK Bundle](../../actions/workflows/build-bundle-ipk.yml/badge.svg)

](../../actions/workflows/build-bundle-ipk.yml)

---

## 支持设备

| 设备 | SoC | 闪存 | 内存 |
|---|---|---|---|
| 华硅科技 WH3000 Pro | MediaTek MT7981（Filogic 820）| eMMC 128MB | 512MB DDR4 |

---

## 固件特性

- 🚀 **GitHub Actions 全自动编译**，无需本地环境
- 📦 **精简优化**，禁用不必要的内核调试选项，降低 OOM 风险
- 🌐 **LuCI 界面加速**，编译期压缩 JS/CSS，启用 uhttpd gzip
- 📡 **IPTV 管理器**，自研 msd_lite / rtp2HTTPd 二合一界面
- 🔌 **5G/4G 模组支持**，集成 Quectel 系列模块管理
- 🔒 **完整 VPN 栈**，OpenVPN / StrongSwan / L2TP / SSR-Plus

---

## 内置插件

### 网络工具
| 插件 | 说明 |
|---|---|
| SSR-Plus | 代理上网（ShadowSocksR Plus+） |
| OpenVPN / StrongSwan / L2TP | 企业级 VPN |
| DDNS（阿里云 / DNSPod）| 动态域名解析 |
| UPnP | 端口自动映射 |
| Lucky | 内网穿透 / 反向代理 |
| nlbwmon | 网络带宽监控 |

### IPTV / 流媒体
| 插件 | 说明 |
|---|---|
| **luci-app-iptv-manager** | 🆕 自研二合一 IPTV 管理界面（详见下文） |
| msd_lite | 轻量 UDP 组播 → HTTP 转发 |
| rtp2httpd | 功能完整的 RTP/UDP → HTTP 代理，支持 Web 播放器、M3U 频道列表 |

### 文件共享
| 插件 | 说明 |
|---|---|
| Samba4 | Windows 文件共享（SMB） |
| vsftpd | FTP 服务器 |
| WebDAV | WebDAV 文件服务 |

### 系统工具
| 插件 | 说明 |
|---|---|
| Docker / Dockerman | 容器化应用管理 |
| Qmodem | 5G/4G 模组管理（支持 Quectel） |
| vlmcsd | KMS 激活服务器 |
| 定时重启 | 计划任务自动重启 |

---

## 自研插件：IPTV 管理器

位于 `custom-packages/luci-app-iptv-manager`，将 **msd_lite** 与 **rtp2HTTPd**
整合进同一个 LuCI 界面，两套配置独立保存，一键切换，互不干扰。

### 功能特点
- **程序选择**：下拉切换 msd_lite / rtp2HTTPd，界面自动显示对应参数
- **运行状态**：页面顶部实时显示当前程序运行状态与监听端口
- **msd_lite 配置**：接口、端口、缓冲区、流类型、组播重加入间隔
- **rtp2HTTPd 配置**：HTTP 监听、简单/高级接口模式、M3U 频道列表、
  Web 播放器路径、udpxy 兼容 URL、RTSP、FCC、FFmpeg 截图等完整参数
- **独立 IPK 发布**：可通过 GitHub Releases 页面下载，无需重新编译固件

### 独立安装（无需刷固件）
从 [Releases](../../releases) 页面下载 `iptv-manager-bundle_*.ipk`，
上传到路由器后 SSH 执行：
```sh
opkg install /tmp/iptv-manager-bundle_*.ipk
