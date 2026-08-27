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
#  10. Linux 6.18 MediaTek WED 942 自动兼容
#
# ================================================================

set -euo pipefail


# ================================================================
# 基础信息
# ================================================================

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


# ------------------------------------------------
# 防止重复写入 feeds.conf.default
# ------------------------------------------------

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
#
# 原始问题：
#
#   firmware：
#       0x1ab0000
#
#   约：
#       27328 KB
#
# 扩展后：
#
#   firmware：
#       0x1fb0000
#
#   约：
#       32448 KB
#
# 移除：
#
#   mini
#   oem
#
# 注意：
#
#   此修改只针对 RE-SP-01B。
#
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


    # firmware：
    # 0x1ab0000 → 0x1fb0000

    src = src.replace(
        "reg = <0x50000 0x1ab0000>",
        "reg = <0x50000 0x1fb0000>"
    )


    # 删除 mini

    src = re.sub(
        r'\n\s*partition@1b00000\s*\{[^}]*\}\s*;',
        '',
        src,
        flags=re.DOTALL
    )


    # 删除 oem

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
#
# WH3000 / WH3000 Pro：
#
#   Linux 6.18
#
#   hrtimer_init()
#       ↓
#   hrtimer_setup()
#
#
# RE-SP-01B：
#
#   Linux 5.x
#
#   继续使用 hrtimer_init()
#
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


    # --------------------------------------------------------
    # 已经修复
    # --------------------------------------------------------

    if "KERNEL_VERSION(6, 17, 0)" in src:

        print(
            f"  [OK] 已经存在版本兼容：{fname}"
        )

        return


    # --------------------------------------------------------
    # 没有 hrtimer_init
    # --------------------------------------------------------

    if "hrtimer_init" not in src:

        print(
            f"  [OK] 没有 hrtimer_init：{fname}"
        )

        return


    # --------------------------------------------------------
    # 找 callback
    # --------------------------------------------------------

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


    # --------------------------------------------------------
    # linux/version.h
    # --------------------------------------------------------

    if "#include <linux/version.h>" not in src:

        src = re.sub(
            r"^(#include\s)",
            r"#include <linux/version.h>\n\1",
            src,
            count=1,
            flags=re.MULTILINE
        )


    # --------------------------------------------------------
    # hrtimer_init
    # --------------------------------------------------------

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


    # --------------------------------------------------------
    # qma_setting_store
    # --------------------------------------------------------

    if fname == "qmi_wwan_f.c":

        src, _ = re.subn(

            r"^int\s+qma_setting_store\s*\(",

            "static int qma_setting_store(",

            src,

            flags=re.MULTILINE
        )


    # --------------------------------------------------------
    # 保存
    # --------------------------------------------------------

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


echo "============================================================"
echo ">>> 7. Linux 6.18 MediaTek WED 942 兼容修复"
echo "============================================================"

WED_PATCH="target/linux/mediatek/patches-6.18/942-net-ethernet-mtk_wed-move-cpuboot-in-a-dedicated-dts.patch"

if [ ! -f "$WED_PATCH" ]; then

    echo "  [WARN] 未找到 942 WED 补丁："
    echo "  $WED_PATCH"

else

    python3 << 'PYEOF'

from pathlib import Path

PATCH = Path(
    "target/linux/mediatek/patches-6.18/"
    "942-net-ethernet-mtk_wed-move-cpuboot-in-a-dedicated-dts.patch"
)

src = PATCH.read_text(
    encoding="utf-8"
)

# ============================================================
# 如果已经修复过，则不重复修改
# ============================================================

if (
    "+\two_w32(wo, boot_cr, mem_region[MTK_WED_WO_REGION_EMI].phy_addr >> 16);"
    in src
    and
    "+\tval = wo_r32(wo, MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR) |"
    in src
):

    print("  [OK] 942 补丁已经完成 wo 参数兼容")
    raise SystemExit(0)


# ============================================================
# 原始 LEDE 942 第 3 个 hunk
#
# Linux 6.18.45 的源码相比旧版本多了 WED v3 判断，
# 所以原来的 13 行 hunk 无法直接匹配。
# ============================================================

old = """@@ -364,13 +381,13 @@ mtk_wed_mcu_load_firmware(struct mtk_wed
 \t\tboot_cr = MTK_WO_MCU_CFG_LS_WA_BOOT_ADDR_ADDR;
 \telse
 \t\tboot_cr = MTK_WO_MCU_CFG_LS_WM_BOOT_ADDR_ADDR;
-\two_w32(boot_cr, mem_region[MTK_WED_WO_REGION_EMI].phy_addr >> 16);
+\two_w32(wo, boot_cr, mem_region[MTK_WED_WO_REGION_EMI].phy_addr >> 16);
 \t/* wo firmware reset */
-\two_w32(MTK_WO_MCU_CFG_LS_WF_MCCR_CLR_ADDR, 0xc00);
+\two_w32(wo, MTK_WO_MCU_CFG_LS_WF_MCCR_CLR_ADDR, 0xc00);
 
-\tval = wo_r32(MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR) |
+\tval = wo_r32(wo, MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR) |
 \t      MTK_WO_MCU_CFG_LS_WF_WM_WA_WM_CPU_RSTB_MASK;
-\two_w32(MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR, val);
+\two_w32(wo, MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR, val);
 out:
 \trelease_firmware(fw);
"""


# ============================================================
# Linux 6.18.45 当前源码对应版本
#
# 注意：
#
# 这里仅修改 wo_r32 / wo_w32 参数。
#
# 不再重复加入 WED v3 判断。
# ============================================================

new = """@@ -364,17 +381,17 @@ mtk_wed_mcu_load_firmware(struct mtk_wed
 \t\tboot_cr = MTK_WO_MCU_CFG_LS_WA_BOOT_ADDR_ADDR;
 \telse
 \t\tboot_cr = MTK_WO_MCU_CFG_LS_WM_BOOT_ADDR_ADDR;
-\two_w32(boot_cr, mem_region[MTK_WED_WO_REGION_EMI].phy_addr >> 16);
+\two_w32(wo, boot_cr, mem_region[MTK_WED_WO_REGION_EMI].phy_addr >> 16);
 \t/* wo firmware reset */
-\two_w32(MTK_WO_MCU_CFG_LS_WF_MCCR_CLR_ADDR, 0xc00);
+\two_w32(wo, MTK_WO_MCU_CFG_LS_WF_MCCR_CLR_ADDR, 0xc00);
 
-\tval = wo_r32(MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR) |
+\tval = wo_r32(wo, MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR) |
 \t      MTK_WO_MCU_CFG_LS_WF_WM_WA_WM_CPU_RSTB_MASK;
-\two_w32(MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR, val);
+\two_w32(wo, MTK_WO_MCU_CFG_LS_WF_MCU_CFG_WM_WA_ADDR, val);
 out:
 \trelease_firmware(fw);
"""


# ============================================================
# 检查原始结构
# ============================================================

if old not in src:

    print("  [ERROR] 找不到 LEDE 原始 942 第 3 个 hunk")

    print()
    print("  当前 942 补丁结构与预期不同。")
    print("  为避免破坏内核补丁，本次停止编译。")

    raise SystemExit(1)


# ============================================================
# 替换
# ============================================================

src = src.replace(
    old,
    new,
    1
)


# ============================================================
# 写回
# ============================================================

PATCH.write_text(
    src,
    encoding="utf-8"
)


print("  ✓ 942 第 3 个 hunk 已适配 Linux 6.18.45")
print("  ✓ 仅修复 wo_r32 / wo_w32 参数")
print("  ✓ 保留 Linux 6.18 WED v3 原有判断")
print("  ✓ Patch 格式保持标准 unified diff")

PYEOF

fi


echo
echo "============================================================"
echo ">>> WED 942 补丁最终检查"
echo "============================================================"

if [ -f "$WED_PATCH" ]; then

    echo "── Patch 文件前 100 行检查 ──"

    sed -n '1,100p' "$WED_PATCH"

    echo
    echo "── Patch 基本格式检查 ──"

    if grep -q '^--- a/drivers/net/ethernet/mediatek/mtk_wed_mcu.c' "$WED_PATCH" \
       && grep -q '^+++ b/drivers/net/ethernet/mediatek/mtk_wed_mcu.c' "$WED_PATCH" \
       && grep -q '^--- a/drivers/net/ethernet/mediatek/mtk_wed_wo.h' "$WED_PATCH" \
       && grep -q '^+++ b/drivers/net/ethernet/mediatek/mtk_wed_wo.h' "$WED_PATCH"; then

        echo "  ✓ 942 Patch 文件格式正常"

    else

        echo "  ❌ 942 Patch 文件格式异常"

        exit 1

    fi

fi

echo
echo ">>> MediaTek WED 942 兼容修复完成"
)

PYEOF

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
# 9. 输出 WED 补丁关键内容
# ================================================================

if [ -f "$WED_PATCH" ]; then

    echo "============================================================"
    echo ">>> WED 942 补丁检查"
    echo "============================================================"

    if grep -q \
      "mtk_wed_is_v3_or_greater(wo->hw)" \
      "$WED_PATCH"; then

        echo "✅ 942 已包含 Linux 6.18 WED v3 兼容"

    else

        echo "❌ 942 未包含 WED v3 兼容"

        exit 1

    fi

fi


# ================================================================
# 10. 完成
# ================================================================

echo
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
echo "  ✓ Linux 6.18 MediaTek WED 942 修复"

echo
echo "============================================================"
