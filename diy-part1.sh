#!/bin/bash
# DIY 脚本第一部分：添加自定义软件源
# 运行时机：在 LEDE 源码目录内，feeds update 执行之前

set -euo pipefail

# ─── 自定义 Feeds ─────────────────────────────────────────

echo "src-git lucky https://github.com/gdy666/luci-app-lucky.git" \
    >> feeds.conf.default

echo "src-git qmodem https://github.com/FUjr/modem_feeds.git;main" \
    >> feeds.conf.default

echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git" \
    >> feeds.conf.default

# ─── 直接克隆到 package 目录 ──────────────────────────────

# msd_lite：使用 -c <config_file> 启动，其 init.d 负责读取配置并生成启动参数
# 保留官方 init.d，由我们的统一管理脚本委托调用
git clone --depth=1 \
    https://github.com/ximiTech/msd_lite \
    package/msd_lite

# ─── 复制仓库内自定义包 ──────────────────────────────────

cp -r "${GITHUB_WORKSPACE}/custom-packages/luci-app-iptv-manager" \
      package/luci-app-iptv-manager

# ─── 完成 ────────────────────────────────────────────────

echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default
