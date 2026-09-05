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

# ════════════════════════════════════════════════════════════
# ★ Fix-1：Linux 6.18 MediaTek WED 重复 backport 清理
#
# 根因：LEDE 将 MediaTek 内核升至 6.18.45+ 后，上游已包含
#       cpuboot / ILM / DLM 独立 DTS 节点相关改动。
#       LEDE patches-6.18 中 941～949 是对应的旧版 backport，
#       当这些改动已存在于当前内核源码时，再次 apply 就会：
#         Hunk FAILED → 整个内核编译中止
#
#       本脚本采用"检测后清理"策略，批量删除 941～949 区间，
#       避免 LEDE 每次升内核都要逐个手工追 patch。
#
#       这些 patch 均针对 MT7986 DTS，本项目设备不受影响：
#         WH3000 / WH3000 Pro → MT7981
#         RE-SP-01B            → MT7621
# ════════════════════════════════════════════════════════════

echo ">>> [Fix-1] 检查 Linux 6.18 WED backport 冲突..."

MTPATCH="target/linux/mediatek/patches-6.18"

if [ ! -d "$MTPATCH" ]; then
    echo "  [WARN] $MTPATCH 不存在，跳过"
else
    echo "  清理前 940 段 MediaTek WED patch："
    find "$MTPATCH" \
        -maxdepth 1 -type f -name '94[0-9]-*.patch' \
        -printf '    %f\n' 2>/dev/null | sort || true
    echo

    for N in 941 942 943 944 945 946 947 948 949; do
        for PATCH in "$MTPATCH"/"${N}"-*.patch; do
            [ -e "$PATCH" ] || continue
            echo "  [REMOVE] $(basename "$PATCH")"
            rm -f "$PATCH"
        done
    done

    echo
    echo "  清理后 940 段 MediaTek WED patch："
    find "$MTPATCH" \
        -maxdepth 1 -type f -name '94[0-9]-*.patch' \
        -printf '    %f\n' 2>/dev/null | sort || true
fi

echo ">>> [Fix-1] WED backport 清理完成"

# ════════════════════════════════════════════════════════════
# ★ Fix-2：RE-SP-01B flash 分区扩展至完整 32MB
#
# 根因（LEDE issue #5882）：
#   RE-SP-01B 的 flash 分区表预留了 mini(4MB) + oem(1MB) 两个厂商分区，
#   导致 firmware 分区只有 27328k（约 27MB）。
#   插件一多，sysupgrade.bin 超出 IMAGE_SIZE 限制，LEDE 静默跳过生成——
#   不报错，不警告，只留下 initramfs-kernel.bin。
#
# 修复方案（社区验证，AmadeusGhost @ issue #5882）：
#   ① 修改 DTS：移除 mini/oem 分区，firmware 扩展到 0x1fb0000
#   ② 修改 mt7621.mk：IMAGE_SIZE 27328k → 32448k
#
# ⚠️  前提：设备已刷 Breed 或第三方 bootloader。
# ════════════════════════════════════════════════════════════

echo ">>> [Fix-2] 修复 RE-SP-01B flash 分区限制（扩展至完整 32MB）..."

DTS="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"
MK="target/linux/ramips/image/mt7621.mk"

if [ ! -f "$DTS" ] || [ ! -f "$MK" ]; then
    echo "  [WARN] RE-SP-01B 源文件不存在，跳过 flash 扩展"
else
    python3 << 'PYEOF'
import re, os

DTS = 'target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts'
src = open(DTS, encoding='utf-8').read()

if '0x1fb0000' in src:
    print('  [OK]   DTS 已扩展，无需重复修改')
else:
    orig = src
    src = src.replace('reg = <0x50000 0x1ab0000>', 'reg = <0x50000 0x1fb0000>')
    src = re.sub(r'\n\s*partition@1b00000\s*\{[^}]*\}\s*;', '', src, flags=re.DOTALL)
    src = re.sub(r'\n\s*partition@1f00000\s*\{[^}]*\}\s*;', '', src, flags=re.DOTALL)
    if src != orig:
        open(DTS, 'w', encoding='utf-8').write(src)
        print('  ✓ DTS：firmware 0x1ab0000 → 0x1fb0000，移除 mini/oem')
    else:
        print('  [WARN] DTS 内容未变化，可能源码格式有变')

MK = 'target/linux/ramips/image/mt7621.mk'
src = open(MK, encoding='utf-8').read()
if 'jdcloud_re-sp-01b' not in src:
    print('  [WARN] mt7621.mk 未找到 jdcloud_re-sp-01b，跳过')
else:
    new = re.sub(
        r'(define Device/jdcloud_re-sp-01b.*?^endef)',
        lambda m: m.group(0).replace('IMAGE_SIZE := 27328k', 'IMAGE_SIZE := 32448k'),
        src, flags=re.DOTALL | re.MULTILINE)
    if new != src:
        open(MK, 'w', encoding='utf-8').write(new)
        print('  ✓ mt7621.mk：IMAGE_SIZE 27328k → 32448k')
    else:
        print('  [OK]   mt7621.mk 已是 32448k 或无需修改')

print('>>> [Fix-2] 完成')
PYEOF
fi

# ════════════════════════════════════════════════════════════
# ★ Fix-3：QMI WWAN 驱动多内核版本兼容
#
# 根因：同一份 C 源码在两种内核下编译：
#   WH3000/Pro → Linux 6.18（hrtimer_init 已删除，必须用 hrtimer_setup）
#   RE-SP-01B  → Linux 5.10（hrtimer_setup 尚不存在，必须用 hrtimer_init）
#
# 修复：用 #if LINUX_VERSION_CODE >= KERNEL_VERSION(6,17,0)
#       条件编译，让同一份源码同时兼容两个内核版本。
#
# 附修：qma_setting_store 缺 static（-Werror=missing-prototypes）
# ════════════════════════════════════════════════════════════

echo ">>> [Fix-3] 修复 QMI WWAN 驱动多内核兼容性..."

python3 << 'PYEOF'
import re, os

TARGET_FILES = [
    'package/wwan/driver/fibocom_QMI_WWAN/src/qmi_wwan_f.c',
    'package/wwan/driver/quectel_QMI_WWAN/src/qmi_wwan_f.c',
    'package/wwan/driver/quectel_QMI_WWAN/src/qmi_wwan_q.c',
]

def fix(fpath):
    fname = os.path.basename(fpath)
    if not os.path.exists(fpath):
        print(f'  [SKIP] 不存在: {fpath}'); return
    src = open(fpath, encoding='utf-8', errors='replace').read()
    orig = src
    if 'KERNEL_VERSION(6, 17, 0)' in src:
        print(f'  [OK]   已含版本条件: {fname}'); return
    if 'hrtimer_init' not in src:
        print(f'  [OK]   无需修复: {fname}'); return
    m = re.search(r'agg_hrtimer\.function\s*=\s*(\w+)\s*;', src)
    if not m:
        print(f'  [WARN] 找不到 .function=: {fname}'); return
    cb = m.group(1)
    if '#include <linux/version.h>' not in src:
        src = re.sub(r'^(#include\s)', r'#include <linux/version.h>\n\1',
                     src, count=1, flags=re.MULTILINE)
    def repl(m):
        i = m.group(1)
        return (f'{i}#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)\n'
                f'{i}\thrtimer_setup(&priv->agg_hrtimer, {cb}, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n'
                f'{i}#else\n'
                f'{i}\thrtimer_init(&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n'
                f'{i}#endif')
    src, n = re.subn(
        r'^([ \t]*)hrtimer_init\s*\(\s*&\s*priv\s*->\s*agg_hrtimer\s*,'
        r'\s*CLOCK_MONOTONIC\s*,\s*HRTIMER_MODE_REL\s*\)\s*;',
        repl, src, flags=re.MULTILINE)
    if n == 0:
        print(f'  [WARN] hrtimer_init 未命中: {fname}'); return
    if fname == 'qmi_wwan_f.c':
        src, _ = re.subn(r'^int\s+qma_setting_store\s*\(',
                         'static int qma_setting_store(', src, flags=re.MULTILINE)
    if src != orig:
        open(fpath, 'w', encoding='utf-8').write(src)
        print(f'  ✓ 修复完成: {fname}  (callback={cb})')

for f in TARGET_FILES:
    fix(f)
print('>>> [Fix-3] 完成')
PYEOF
# ─── 克隆 songloft-for-router OpenWrt 包 ─────────────────
git clone --depth=1 \
    https://github.com/songloft-org/songloft-for-router.git \
    /tmp/songloft-for-router
cp -r /tmp/songloft-for-router/openwrt/songloft \
    package/songloft
cp -r /tmp/songloft-for-router/openwrt/luci-app-songloft \
    package/luci-app-songloft
rm -rf /tmp/songloft-for-router
echo ">>> songloft 包已加入编译环境"
# ─── 完成 ────────────────────────────────────────────────
echo ""
echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default

