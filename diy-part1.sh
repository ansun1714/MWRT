#!/bin/bash

# DIY 脚本第一部分：添加自定义软件源
# 运行时机：在 MWRT 源码目录内，feeds update 执行之前

set -euo pipefail

# ─── 自定义 Feeds ─────────────────────────────────────────

echo "src-git lucky https://github.com/gdy666/luci-app-lucky.git" \
>> feeds.conf.default

echo "src-git qmodem https://github.com/FUjr/modem_feeds.git;main" \
>> feeds.conf.default

echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git" \
>> feeds.conf.default

echo "src-git helloworld https://github.com/fw876/helloworld.git" \
>> feeds.conf.default

# ─── 直接克隆到 package 目录 ──────────────────────────────

git clone --depth=1 \
    https://github.com/ximiTech/msd_lite \
    package/msd_lite

# ─── 复制仓库内自定义包 ──────────────────────────────────

cp -r "${GITHUB_WORKSPACE}/custom-packages/luci-app-iptv-manager" \
    package/luci-app-iptv-manager

# ── 克隆 OpenClash ───────────────────────────────────────

git clone --depth=1 \
    https://github.com/vernesong/OpenClash.git \
    /tmp/OpenClash
cp -r /tmp/OpenClash/luci-app-openclash package/
rm -rf /tmp/OpenClash

# ─── 内核 6.17+ QMI WWAN 驱动兼容修复 ──────────────────────────────────
#
# 背景：Linux 6.17 删除了 hrtimer_init()，改用 hrtimer_setup()
#   旧：hrtimer_init(&timer, clock, mode); timer.function = cb;
#   新：hrtimer_setup(&timer, cb, clock, mode);
#
# fibocom_QMI_WWAN / quectel_QMI_WWAN 是 lede 内置包（非外部 feed），
# 源文件在 package/wwan/driver/XXX/src/ 下，diy-part1.sh 运行时已存在。
# 路径确定，无需搜索，直接 sed 修复。
#
# 同修：qma_setting_store 缺 static 声明（-Werror=missing-prototypes）

echo ">>> 修复 QMI WWAN 驱动内核 6.17+ 兼容性..."

for SRCDIR in \
    "package/wwan/driver/fibocom_QMI_WWAN/src" \
    "package/wwan/driver/quectel_QMI_WWAN/src"
do
    if [ ! -d "$SRCDIR" ]; then
        echo "  [跳过] 目录不存在: $SRCDIR"
        continue
    fi

    for F in "${SRCDIR}/qmi_wwan_f.c" "${SRCDIR}/qmi_wwan_q.c"; do
        [ -f "$F" ] || continue

        if ! grep -q 'hrtimer_init' "$F"; then
            echo "  [OK]   已无需修复: $F"
            continue
        fi

        # 提取回调函数名（不硬编码，自动适配将来版本）
        CB=$(grep -m1 'agg_hrtimer\.function' "$F" \
             | sed 's/.*=[[:space:]]*//;s/[[:space:]]*;//')

        if [ -z "$CB" ]; then
            echo "  [WARN] 找不到回调函数名，跳过: $F"
            continue
        fi

        # 步骤1：hrtimer_init → hrtimer_setup（将回调作为第2参数）
        sed -i \
"s/hrtimer_init(\&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL)/hrtimer_setup(\&priv->agg_hrtimer, ${CB}, CLOCK_MONOTONIC, HRTIMER_MODE_REL)/g" \
            "$F"

        # 步骤2：删除现在多余的 .function = cb 赋值整行
        sed -i "/agg_hrtimer\.function[[:space:]]*=/d" "$F"

        # 步骤3：qma_setting_store 加 static（仅 qmi_wwan_f.c）
        case "$(basename "$F")" in
            qmi_wwan_f.c)
                sed -i 's/^int qma_setting_store(/static int qma_setting_store(/' "$F" \
                    2>/dev/null || true
                ;;
        esac

        echo "  [FIXED] $F  callback=$CB"
    done
done

echo ">>> QMI WWAN 修复完成"

# ─── 完成 ────────────────────────────────────────────────

echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default
