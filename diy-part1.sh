#!/bin/bash

# DIY 脚本第一部分：添加自定义软件源
# 运行时机：在 MWRT 源码目录内，feeds update 执行之前

set -euo pipefail

# ─── 自定义 Feeds ─────────────────────────────────────────
# 注意：helloworld 已在 LEDE feeds.conf.default 内置，不要重复添加

echo "src-git lucky https://github.com/gdy666/luci-app-lucky.git" \
>> feeds.conf.default

echo "src-git qmodem https://github.com/FUjr/modem_feeds.git;main" \
>> feeds.conf.default

echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git" \
>> feeds.conf.default

# ─── 直接克隆到 package 目录 ──────────────────────────────

git clone --depth=1 \
    https://github.com/ximiTech/msd_lite \
    package/msd_lite

cp -r "${GITHUB_WORKSPACE}/custom-packages/luci-app-iptv-manager" \
    package/luci-app-iptv-manager

git clone --depth=1 \
    https://github.com/vernesong/OpenClash.git \
    /tmp/OpenClash
cp -r /tmp/OpenClash/luci-app-openclash package/
rm -rf /tmp/OpenClash

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

# ─── 克隆 luci-app-webdav ────────────────────────────────
git clone --depth=1 \
    -b openwrt-24.10 \
    https://github.com/sbwml/luci-app-webdav.git \
    package/luci-app-webdav
echo ">>> luci-app-webdav 已加入编译环境"

# ════════════════════════════════════════════════════════════
# ★ Fix-1：Linux 6.18 MediaTek WED 重复 backport 清理
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

    # ★ 注意：变量引用必须用 "$MTPATCH" 和 "${N}"，不能有任何多余字符
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
# ════════════════════════════════════════════════════════════

echo ">>> [Fix-2] 修复 RE-SP-01B flash 分区限制..."

DTS="target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts"
MK="target/linux/ramips/image/mt7621.mk"

if [ ! -f "$DTS" ] || [ ! -f "$MK" ]; then
    echo "  [WARN] RE-SP-01B 源文件不存在，跳过"
else
    python3 << 'PYEOF'
import re, os

DTS = 'target/linux/ramips/dts/mt7621_jdcloud_re-sp-01b.dts'
src = open(DTS, encoding='utf-8').read()
if '0x1fb0000' in src:
    print('  [OK]   DTS 已扩展')
else:
    orig = src
    src = src.replace('reg = <0x50000 0x1ab0000>', 'reg = <0x50000 0x1fb0000>')
    src = re.sub(r'\n\s*partition@1b00000\s*\{[^}]*\}\s*;', '', src, flags=re.DOTALL)
    src = re.sub(r'\n\s*partition@1f00000\s*\{[^}]*\}\s*;', '', src, flags=re.DOTALL)
    if src != orig:
        open(DTS, 'w', encoding='utf-8').write(src)
        print('  ✓ DTS：firmware 0x1ab0000 → 0x1fb0000，移除 mini/oem')

MK = 'target/linux/ramips/image/mt7621.mk'
src = open(MK, encoding='utf-8').read()
new = re.sub(
    r'(define Device/jdcloud_re-sp-01b.*?^endef)',
    lambda m: m.group(0).replace('IMAGE_SIZE := 27328k', 'IMAGE_SIZE := 32448k'),
    src, flags=re.DOTALL|re.MULTILINE)
if new != src:
    open(MK, 'w', encoding='utf-8').write(new)
    print('  ✓ mt7621.mk：IMAGE_SIZE 27328k → 32448k')
else:
    print('  [OK]   mt7621.mk 无需修改')
print('>>> [Fix-2] 完成')
PYEOF
fi

# ════════════════════════════════════════════════════════════
# ★ Fix-3：QMI WWAN 驱动多内核版本兼容
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

# ════════════════════════════════════════════════════════════
# ★ Fix-4：kmod-crypto-chacha20poly1305 的 libpoly1305.ko 依赖
#
# 根因：Linux 6.18.49 的 chacha20poly1305.ko 依赖 lib/crypto/libpoly1305.ko
#       但 LEDE 的 kmod-crypto-poly1305 只打包 crypto/poly1305_generic.ko，
#       没有包含 lib/crypto/libpoly1305.ko → 打包失败。
#
# 修法：把 lib/crypto/libpoly1305.ko 加入 kmod-crypto-poly1305 的 FILES。
#       用 $(wildcard ...) 保证旧内核上不报错（文件不存在时返回空）。
#       kmod-crypto-chacha20poly1305 已依赖 kmod-crypto-poly1305，
#       无需修改任何依赖关系，改动最小。
#
# 为何之前各方案均失败：
#   ChatGPT："+LINUX_6_18:..."  → LEDE 里无此符号，条件永假
#   Grok：   "@lt6.18"          → LEDE crypto.mk 里根本没有此注解
# ════════════════════════════════════════════════════════════

echo ">>> [Fix-4] 修复 kmod-crypto-chacha20poly1305 libpoly1305.ko 依赖..."

python3 << 'PYEOF'
import re, sys, os

MK = 'package/kernel/linux/modules/crypto.mk'
if not os.path.exists(MK):
    print('  [SKIP] crypto.mk 不存在'); sys.exit(0)

src = open(MK, encoding='utf-8').read()

# 幂等：已修复则跳过
if 'lib/crypto/libpoly1305' in src:
    print('  [OK] crypto.mk 已含 libpoly1305.ko，无需重复修复')
    sys.exit(0)

orig = src
fixed = False

# ── 方法1：精确字符串替换（适配标准 LEDE crypto.mk 格式）──────────
OLD = 'FILES:=$(LINUX_DIR)/crypto/poly1305_generic.ko'
NEW = ('FILES:=$(LINUX_DIR)/crypto/poly1305_generic.ko \\\n'
       '\t\t$(wildcard $(LINUX_DIR)/lib/crypto/libpoly1305.ko)')

if OLD in src:
    src = src.replace(OLD, NEW, 1)
    fixed = True
    print('  ✓ [方法1] 精确替换成功')

# ── 方法2：正则替换（处理 FILES 格式变体）──────────────────────────
if not fixed:
    m = re.search(
        r'(define KernelPackage/crypto-poly1305\b.*?^endef)',
        src, flags=re.DOTALL | re.MULTILINE
    )
    if m:
        block = m.group(1)
        new_block = re.sub(
            r'(FILES\s*:=\s*\$\(LINUX_DIR\)/[^\n]*poly1305[^\n]*\.ko)',
            r'\1 \\\n\t\t$(wildcard $(LINUX_DIR)/lib/crypto/libpoly1305.ko)',
            block
        )
        if new_block != block:
            src = src[:m.start()] + new_block + src[m.end():]
            fixed = True
            print('  ✓ [方法2] 正则替换成功')
        else:
            print('  [方法2 未命中] kmod-crypto-poly1305 FILES 行诊断：')
            for i, line in enumerate(block.split('\n'), 1):
                if 'poly1305' in line.lower() or 'FILES' in line:
                    print(f'    L{i}: {line}')
    else:
        print('  [WARN] 未找到 KernelPackage/crypto-poly1305 定义')

if not fixed:
    print('  [WARN] Fix-4 未能修改 crypto.mk，请检查上方诊断输出')
    sys.exit(0)  # 不中断，让后续步骤继续

open(MK, 'w', encoding='utf-8').write(src)
print('  ✓ crypto.mk 写入完成')
print('    kmod-crypto-poly1305 现在包含：')
print('      · crypto/poly1305_generic.ko       (所有内核)')
print('      · lib/crypto/libpoly1305.ko         (kernel 6.18.49+, wildcard)')
PYEOF
echo ">>> [Fix-4] 完成"

# ─── 完成 ────────────────────────────────────────────────

echo ""
echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default
