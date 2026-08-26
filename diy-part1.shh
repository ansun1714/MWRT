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

# ─── RE-SP-01B：扩展 flash 分区到完整 32MB ──────────────────────────────
#
# 问题根因（LEDE issue #5882）：
#   RE-SP-01B 的 flash 分区表预留了 mini(4MB) + oem(1MB) 两个厂商分区，
#   导致 firmware 分区只有 27328k（约 27MB）。
#   插件一多，sysupgrade.bin 超出 IMAGE_SIZE 限制，LEDE 静默跳过生成——
#   不报错，不警告，只留下 initramfs-kernel.bin。
#
# 修复方案（社区验证，AmadeusGhost @ issue #5882）：
#   ① 修改 DTS：移除 mini/oem 分区，firmware 分区扩展到 0x1fb0000（32MB-256KB）
#   ② 修改 mt7621.mk：IMAGE_SIZE 从 27328k 改为 32448k
#
# ⚠️  前提：设备已刷 Breed 或第三方 bootloader。
#     原厂 bootloader 依赖 mini 分区做 Web 救砖，扩展分区后将无法使用原厂 Web 恢复。
#     已刷 Breed 的用户不受影响。

echo ">>> 修复 RE-SP-01B flash 分区限制（扩展至完整 32MB）..."

DTS="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"
MK="target/linux/ramips/image/mt7621.mk"

if [ ! -f "$DTS" ] || [ ! -f "$MK" ]; then
    echo "  [WARN] RE-SP-01B 源文件不存在，跳过 flash 扩展"
else
    python3 << 'PYEOF'
import re, os

# ── 1. 修改 DTS ────────────────────────────────────────────────────────────
DTS = 'target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts'
src = open(DTS, encoding='utf-8').read()

if '0x1fb0000' in src:
    print('  [OK]   DTS 已扩展，无需重复修改')
else:
    orig = src

    # 步骤1：firmware 分区 size 从 0x1ab0000 → 0x1fb0000
    # 对应：27328k → 32448k（移除 mini + oem 后的完整可用空间）
    src = src.replace(
        'reg = <0x50000 0x1ab0000>',
        'reg = <0x50000 0x1fb0000>'
    )

    # 步骤2：移除 mini 分区定义（partition@1b00000 整块）
    # mini 分区占用 0x1b00000-0x1f00000（4MB），现已并入 firmware
    src = re.sub(
        r'\n\s*partition@1b00000\s*\{[^}]*\}\s*;',
        '',
        src,
        flags=re.DOTALL
    )

    # 步骤3：移除 oem 分区定义（partition@1f00000 整块）
    # oem 分区占用 0x1f00000-0x2000000（1MB），现已并入 firmware
    src = re.sub(
        r'\n\s*partition@1f00000\s*\{[^}]*\}\s*;',
        '',
        src,
        flags=re.DOTALL
    )

    if src != orig:
        open(DTS, 'w', encoding='utf-8').write(src)
        print('  ✓ DTS 分区扩展完成：firmware 0x1ab0000 → 0x1fb0000，移除 mini/oem')
    else:
        print('  [WARN] DTS 内容未变化，可能源码格式有变，请手动检查')

# ── 2. 修改 mt7621.mk ──────────────────────────────────────────────────────
MK = 'target/linux/ramips/image/mt7621.mk'
src = open(MK, encoding='utf-8').read()

if 'jdcloud_re-sp-01b' not in src:
    print('  [WARN] mt7621.mk 中未找到 jdcloud_re-sp-01b，跳过')
elif 'IMAGE_SIZE := 32448k' in src:
    print('  [OK]   mt7621.mk IMAGE_SIZE 已是 32448k，无需修改')
else:
    # 只改 jdcloud_re-sp-01b 块内的 IMAGE_SIZE，不影响其他设备
    def fix_image_size(m):
        return m.group(0).replace('IMAGE_SIZE := 27328k', 'IMAGE_SIZE := 32448k')

    new = re.sub(
        r'(define Device/jdcloud_re-sp-01b.*?^endef)',
        fix_image_size,
        src,
        flags=re.DOTALL | re.MULTILINE
    )

    if new != src:
        open(MK, 'w', encoding='utf-8').write(new)
        print('  ✓ mt7621.mk IMAGE_SIZE：27328k → 32448k')
    else:
        print('  [WARN] mt7621.mk 替换未命中，当前 IMAGE_SIZE 可能已非 27328k')

print('>>> RE-SP-01B flash 分区修复完成')
PYEOF
fi

# ─── QMI WWAN 驱动内核版本兼容修复 ──────────────────────
#
# 问题：fibocom_QMI_WWAN / quectel_QMI_WWAN 是 lede 内置包，
#       源文件在 package/wwan/driver/XXX/src/ 下，
#       同一份 C 代码会被不同内核版本编译：
#         WH3000/Pro → Linux 6.18（hrtimer_init 已删除，必须用 hrtimer_setup）
#         RE-SP-01B  → Linux 5.10（hrtimer_setup 尚未存在，必须用 hrtimer_init）
#
# 修复方案：用 #if LINUX_VERSION_CODE 条件编译，让同一份源码同时兼容两个内核

echo ">>> 修复 QMI WWAN 驱动多内核兼容性..."

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
        print(f'  [SKIP] 不存在: {fpath}')
        return
    src = open(fpath, encoding='utf-8', errors='replace').read()
    orig = src
    if 'KERNEL_VERSION(6, 17, 0)' in src:
        print(f'  [OK]   已含版本条件，无需重复修复: {fname}')
        return
    if 'hrtimer_init' not in src:
        print(f'  [OK]   无 hrtimer_init，无需修复: {fname}')
        return
    m = re.search(r'agg_hrtimer\.function\s*=\s*(\w+)\s*;', src)
    if not m:
        print(f'  [WARN] 找不到 .function= 赋值，跳过: {fname}')
        return
    cb = m.group(1)
    print(f'  callback={cb}')
    if '#include <linux/version.h>' not in src:
        src = re.sub(r'^(#include\s)', r'#include <linux/version.h>\n\1',
                     src, count=1, flags=re.MULTILINE)
    def repl(m):
        indent = m.group(1)
        return (
            f'{indent}#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)\n'
            f'{indent}\thrtimer_setup(&priv->agg_hrtimer, {cb}, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n'
            f'{indent}#else\n'
            f'{indent}\thrtimer_init(&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);\n'
            f'{indent}#endif'
        )
    src, n = re.subn(
        r'^([ \t]*)hrtimer_init\s*\(\s*&\s*priv\s*->\s*agg_hrtimer\s*,'
        r'\s*CLOCK_MONOTONIC\s*,\s*HRTIMER_MODE_REL\s*\)\s*;',
        repl, src, flags=re.MULTILINE)
    if n == 0:
        print(f'  [WARN] hrtimer_init 行未被替换: {fname}')
        return
    if fname == 'qmi_wwan_f.c':
        src, _ = re.subn(r'^int\s+qma_setting_store\s*\(',
                         'static int qma_setting_store(', src, flags=re.MULTILINE)
    if src != orig:
        open(fpath, 'w', encoding='utf-8').write(src)
        print(f'  ✓ 修复完成: {fpath}')

for f in TARGET_FILES:
    print(f'\n[处理] {f}')
    fix(f)
print('\n>>> QMI WWAN 修复完成')
PYEOF

# ─── 完成 ────────────────────────────────────────────────

echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default

