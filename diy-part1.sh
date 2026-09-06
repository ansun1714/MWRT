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
# 基于 nginx WebDAV 模块，轻量级文件共享服务
# 依赖：nginx-mod-dav-ext（nginx 自动作为依赖拉入）
# 架构：all（ARM/MIPS 均适用）
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

    for N in 941 942 943 944 945 946 947 948 949; do
        for PATCH in "\( MTPATCH"/" \){N}"-*.patch; do
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
# ★ Fix-4：Linux 6.18 Crypto Poly1305 模块依赖修复
# ════════════════════════════════════════════════════════════
# LEDE crypto.mk 把 libpoly1305.ko 标成 @lt6.18
# 但 Linux 6.18 的 chacha20poly1305.ko 仍然依赖它
# 打包就会报：
# Package kmod-crypto-chacha20poly1305 is missing dependencies
# for the following libraries: libpoly1305.ko
# ════════════════════════════════════════════════════════════

echo ""
echo ">>> [Fix-4] 修复 Linux 6.18 Crypto Poly1305 依赖..."

CRYPTO_MK="package/kernel/linux/modules/crypto.mk"

if [ ! -f "$CRYPTO_MK" ]; then
    echo "  ❌ 找不到：$CRYPTO_MK"
    exit 1
fi

python3 << 'PYEOF'
import re
import sys

path = "package/kernel/linux/modules/crypto.mk"

with open(path, "r", encoding="utf-8") as f:
    src = f.read()

orig = src

# 1. 6.18 仍然会生成 lib/crypto/libpoly1305.ko，必须打包
src, n = re.subn(
    r'(lib/crypto/libpoly1305\.ko)@lt6\.18',
    r'\1',
    src,
)
print("  {} 去掉 libpoly1305.ko@lt6.18  （命中 {} 处）".format(
    "✓" if n else "[OK]", n
))

# 2. chacha20poly1305 必须依赖 kmod-crypto-lib-poly1305
m = re.search(
    r'define\s+KernelPackage/crypto-chacha20poly1305\b.*?^endef',
    src,
    flags=re.MULTILINE | re.DOTALL,
)

if not m:
    print("  ❌ 找不到 KernelPackage/crypto-chacha20poly1305")
    sys.exit(1)

block = m.group(0)

if "kmod-crypto-lib-poly1305" not in block:
    dep = re.search(
        r'^(\s*DEPENDS\s*:=)([^\n]*)$',
        block,
        flags=re.MULTILINE,
    )
    if not dep:
        print("  ❌ 找不到 crypto-chacha20poly1305 的 DEPENDS")
        sys.exit(1)

    new_block = (
        block[:dep.start()]
        + dep.group(1)
        + dep.group(2).rstrip()
        + " +kmod-crypto-lib-poly1305"
        + block[dep.end():]
    )
    src = src[:m.start()] + new_block + src[m.end():]
    print("  ✓ 已给 crypto-chacha20poly1305 加上 kmod-crypto-lib-poly1305")
else:
    print("  [OK] crypto-chacha20poly1305 已依赖 libpoly1305")

# 3. 如果没有 crypto-lib-poly1305 包，补一个
if not re.search(r'define\s+KernelPackage/crypto-lib-poly1305\b', src):
    poly = '''
define KernelPackage/crypto-lib-poly1305
  TITLE:=Poly1305 library interface
  KCONFIG:=CONFIG_CRYPTO_LIB_POLY1305
  HIDDEN:=1
  FILES:=$(LINUX_DIR)/lib/crypto/libpoly1305.ko
  $(call AddDepends/crypto,+kmod-crypto-hash)
endef

$(eval $(call KernelPackage,crypto-lib-poly1305))
'''
    pos = src.find("define KernelPackage/crypto-manager")
    if pos < 0:
        print("  ❌ 找不到 crypto-manager，无法插入")
        sys.exit(1)
    src = src[:pos] + poly + "\n" + src[pos:]
    print("  ✓ 已注册 KernelPackage/crypto-lib-poly1305")
else:
    print("  [OK] crypto-lib-poly1305 已存在")

if src != orig:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("  ✓ crypto.mk 已写回")
else:
    print("  [OK] crypto.mk 无需改动")

# 4. 最终检查
with open(path, "r", encoding="utf-8") as f:
    check = f.read()

poly = re.search(
    r'define\s+KernelPackage/crypto-lib-poly1305\b.*?^endef',
    check,
    flags=re.MULTILINE | re.DOTALL,
)

if not poly:
    print("  ❌ 最终检查失败：crypto-lib-poly1305 未注册")
    sys.exit(1)

if "lib/crypto/libpoly1305.ko" not in poly.group(0):
    print("  ❌ 最终检查失败：未包含 libpoly1305.ko")
    sys.exit(1)

if "libpoly1305.ko@lt6.18" in poly.group(0):
    print("  ❌ 最终检查失败：@lt6.18 仍在")
    sys.exit(1)

chacha = re.search(
    r'define\s+KernelPackage/crypto-chacha20poly1305\b.*?^endef',
    check,
    flags=re.MULTILINE | re.DOTALL,
)

if not chacha or "kmod-crypto-lib-poly1305" not in chacha.group(0):
    print("  ❌ 最终检查失败：chacha20poly1305 未依赖 libpoly1305")
    sys.exit(1)

print("")
print("  ╔══════════════════════════════════════╗")
print("  ║     Fix-4 Crypto 修复验证通过       ║")
print("  ╚══════════════════════════════════════╝")
PYEOF

echo ">>> [Fix-4] Crypto Poly1305 修复完成"

# ─── 完成 ────────────────────────────────────────────────

echo ""
echo "✅ 软件源配置完成"
echo ""
echo "=== feeds.conf.default ==="
cat feeds.conf.default
