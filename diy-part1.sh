#!/bin/bash

# ================================================================
# MWRT-DONGZAI
# DIY Part 1
#
# 执行位置：
#   MWRT 工作流进入 openwrt 目录后执行
#
# 执行时机：
#   feeds update 之前
#
# 功能：
#   1. 添加 Lucky
#   2. 添加 Qmodem
#   3. 添加 rtp2httpd
#   4. 添加 helloworld
#   5. 加入 MSD Lite
#   6. 加入 IPTV Manager
#   7. 加入 OpenClash
#   8. RE-SP-01B 扩展 firmware 分区
#   9. QMI WWAN 多内核兼容
#  10. Linux 6.18 WED 兼容处理
#
# ================================================================

set -euo pipefail

echo
echo "============================================================"
echo "          MWRT-DONGZAI DIY PART 1"
echo "============================================================"

echo "当前目录：$(pwd)"
echo "GitHub Workspace：${GITHUB_WORKSPACE:-unknown}"

echo


# ================================================================
# 1. 自定义 Feeds
# ================================================================

echo "============================================================"
echo ">>> 1. 添加自定义 Feeds"
echo "============================================================"

add_feed() {

    local line="$1"

    if grep -Fqx "$line" feeds.conf.default 2>/dev/null; then

        echo "  [OK] 已存在：$line"

    else

        echo "$line" >> feeds.conf.default

        echo "  [ADD] $line"

    fi
}


add_feed \
  "src-git lucky https://github.com/gdy666/luci-app-lucky.git"


add_feed \
  "src-git qmodem https://github.com/FUjr/modem_feeds.git;main"


add_feed \
  "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git"


add_feed \
  "src-git helloworld https://github.com/fw876/helloworld.git"


echo


# ================================================================
# 2. MSD Lite
# ================================================================

echo "============================================================"
echo ">>> 2. 添加 MSD Lite"
echo "============================================================"


if [ -d "package/msd_lite" ]; then

    echo "  [OK] package/msd_lite 已存在"

else

    git clone \
        --depth=1 \
        https://github.com/ximiTech/msd_lite \
        package/msd_lite

    echo "  ✓ MSD Lite 克隆完成"

fi


echo


# ================================================================
# 3. 自定义 IPTV Manager
# ================================================================

echo "============================================================"
echo ">>> 3. 添加 IPTV Manager"
echo "============================================================"


IPTV_SRC="${GITHUB_WORKSPACE}/custom-packages/luci-app-iptv-manager"

IPTV_DST="package/luci-app-iptv-manager"


if [ ! -d "$IPTV_SRC" ]; then

    echo "❌ 找不到自定义 IPTV Manager："
    echo "$IPTV_SRC"

    exit 1

fi


rm -rf "$IPTV_DST"


cp -r \
    "$IPTV_SRC" \
    "$IPTV_DST"


echo "  ✓ IPTV Manager 已复制"


echo


# ================================================================
# 4. OpenClash
# ================================================================

echo "============================================================"
echo ">>> 4. 添加 OpenClash"
echo "============================================================"


OPENCLASH_TMP="/tmp/OpenClash"


rm -rf "$OPENCLASH_TMP"


git clone \
    --depth=1 \
    https://github.com/vernesong/OpenClash.git \
    "$OPENCLASH_TMP"


if [ ! -d "$OPENCLASH_TMP/luci-app-openclash" ]; then

    echo "❌ OpenClash 克隆成功，但找不到 luci-app-openclash"

    exit 1

fi


rm -rf package/luci-app-openclash


cp -r \
    "$OPENCLASH_TMP/luci-app-openclash" \
    package/


rm -rf "$OPENCLASH_TMP"


echo "  ✓ OpenClash 已添加"


echo


# ================================================================
# 5. RE-SP-01B Flash 分区扩展
# ================================================================

echo "============================================================"
echo ">>> 5. RE-SP-01B Flash 分区修复"
echo "============================================================"


DTS="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"

MK="target/linux/ramips/image/mt7621.mk"


if [ ! -f "$DTS" ] || [ ! -f "$MK" ]; then

    echo "  [SKIP] RE-SP-01B 源文件不存在"

else

    python3 << 'PYEOF'

import re


DTS = "target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"

MK = "target/linux/ramips/image/mt7621.mk"


# ============================================================
# DTS
# ============================================================

with open(DTS, encoding="utf-8") as f:

    src = f.read()


if "0x1fb0000" in src:

    print("  [OK] DTS 已经扩展")

else:

    orig = src


    src = src.replace(
        "reg = <0x50000 0x1ab0000>",
        "reg = <0x50000 0x1fb0000>"
    )


    src = re.sub(
        r'\n\s*partition@1b00000\s*\{[^}]*\}\s*;',
        '',
        src,
        flags=re.DOTALL
    )


    src = re.sub(
        r'\n\s*partition@1f00000\s*\{[^}]*\}\s*;',
        '',
        src,
        flags=re.DOTALL
    )


    if src != orig:

        with open(DTS, "w", encoding="utf-8") as f:

            f.write(src)


        print(
            "  ✓ DTS 分区："
            "0x1ab0000 → 0x1fb0000"
        )

    else:

        print(
            "  [WARN] DTS 没有发生变化"
        )


# ============================================================
# mt7621.mk
# ============================================================

with open(MK, encoding="utf-8") as f:

    src = f.read()


if "jdcloud_re-sp-01b" not in src:

    print(
        "  [WARN] 找不到 jdcloud_re-sp-01b"
    )


elif "IMAGE_SIZE := 32448k" in src:

    print(
        "  [OK] IMAGE_SIZE 已经是 32448k"
    )


else:

    def fix_image_size(match):

        block = match.group(0)

        return block.replace(
            "IMAGE_SIZE := 27328k",
            "IMAGE_SIZE := 32448k"
        )


    new = re.sub(
        r'(define Device/jdcloud_re-sp-01b.*?^endef)',
        fix_image_size,
        src,
        flags=re.DOTALL | re.MULTILINE
    )


    if new != src:

        with open(MK, "w", encoding="utf-8") as f:

            f.write(new)


        print(
            "  ✓ IMAGE_SIZE："
            "27328k → 32448k"
        )

    else:

        print(
            "  [WARN] IMAGE_SIZE 未发生变化"
        )


print(
    ">>> RE-SP-01B Flash 修复完成"
)

PYEOF

fi


echo


# ================================================================
# 6. QMI WWAN 多内核兼容
# ================================================================

echo "============================================================"
echo ">>> 6. 修复 QMI WWAN 多内核兼容性"
echo "============================================================"


python3 << 'PYEOF'

import re
import os


TARGET_FILES = [

    "package/wwan/driver/fibocom_QMI_WWAN/src/qmi_wwan_f.c",

    "package/wwan/driver/quectel_QMI_WWAN/src/qmi_wwan_f.c",

    "package/wwan/driver/quectel_QMI_WWAN/src/qmi_wwan_q.c",

]


def fix(fpath):

    fname = os.path.basename(fpath)


    if not os.path.exists(fpath):

        print(
            f"  [SKIP] 不存在：{fpath}"
        )

        return


    with open(
        fpath,
        encoding="utf-8",
        errors="replace"
    ) as f:

        src = f.read()


    orig = src


    if "KERNEL_VERSION(6, 17, 0)" in src:

        print(
            f"  [OK] 已经存在版本兼容：{fname}"
        )

        return


    if "hrtimer_init" not in src:

        print(
            f"  [OK] 没有 hrtimer_init：{fname}"
        )

        return


    m = re.search(
        r"agg_hrtimer\.function\s*=\s*(\w+)\s*;",
        src
    )


    if not m:

        print(
            f"  [WARN] 找不到 timer callback：{fname}"
        )

        return


    cb = m.group(1)


    print(
        f"  callback={cb}"
    )


    if "#include <linux/version.h>" not in src:

        src = re.sub(
            r"^(#include\s)",
            r"#include <linux/version.h>\n\1",
            src,
            count=1,
            flags=re.MULTILINE
        )


    def repl(m):

        indent = m.group(1)

        return (
            f"{indent}#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)\n"
            f"{indent}\thrtimer_setup(&priv->agg_hrtimer, {cb}, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n"
            f"{indent}#else\n"
            f"{indent}\thrtimer_init(&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n"
            f"{indent}#endif"
        )


    src, n = re.subn(

        r"^([ \t]*)"
        r"hrtimer_init\s*\("
        r"\s*&\s*priv\s*->\s*agg_hrtimer\s*,"
        r"\s*CLOCK_MONOTONIC\s*,"
        r"\s*HRTIMER_MODE_REL\s*"
        r"\)\s*;",

        repl,

        src,

        flags=re.MULTILINE
    )


    if n == 0:

        print(
            f"  [WARN] hrtimer_init 没有替换：{fname}"
        )

        return


    if fname == "qmi_wwan_f.c":

        src, _ = re.subn(

            r"^int\s+qma_setting_store\s*\(",

            "static int qma_setting_store(",

            src,

            flags=re.MULTILINE
        )


    if src != orig:

        with open(
            fpath,
            "w",
            encoding="utf-8"
        ) as f:

            f.write(src)


        print(
            f"  ✓ 修复完成：{fpath}"
        )


for f in TARGET_FILES:

    print(
        f"\n[处理] {f}"
    )

    fix(f)


print(
    "\n>>> QMI WWAN 修复完成"
)

PYEOF


echo


# ================================================================
# 7. Linux 6.18 MediaTek WED
# ================================================================
#
# 重要：
#
# 不再修改 LEDE 官方 942 patch。
#
# 原因：
#
# LEDE 当前 942 是一个正常的 upstream backport patch，
# 但 Linux 6.18.x 后续已经继续修改 mtk_wed_mcu.c。
#
# 我们之前手工修改 942 会产生：
#
#   malformed patch
#
# 因此这里不再生成、不再重写 unified diff。
#
# ================================================================

echo "============================================================"
echo ">>> 7. Linux 6.18 MediaTek WED 检查"
echo "============================================================"


WED_PATCH="target/linux/mediatek/patches-6.18/942-net-ethernet-mtk_wed-move-cpuboot-in-a-dedicated-dts.patch"


if [ -f "$WED_PATCH" ]; then

    echo "  ✓ 找到 LEDE 官方 942 WED patch"

    echo "  ✓ 不修改官方 patch"

    echo "  ✓ 保持 patch 原始格式"

else

    echo "  [WARN] 没有找到 942 WED patch"

fi


echo


# ================================================================
# 8. 输出最终 Feeds
# ================================================================

echo "============================================================"
echo ">>> 8. 最终 feeds.conf.default"
echo "============================================================"


cat feeds.conf.default


echo


# ================================================================
# 9. 完成
# ================================================================

echo "============================================================"
echo "          ✅ DIY PART 1 全部完成"
echo "============================================================"


echo

echo "已完成："

echo "  ✓ Lucky"

echo "  ✓ Qmodem"

echo "  ✓ rtp2httpd"

echo "  ✓ helloworld"

echo "  ✓ MSD Lite"

echo "  ✓ IPTV Manager"

echo "  ✓ OpenClash"

echo "  ✓ RE-SP-01B Flash 修复"

echo "  ✓ QMI WWAN 多内核兼容"

echo "  ✓ Linux 6.18 WED patch 保持官方原版"


echo

echo "============================================================"
