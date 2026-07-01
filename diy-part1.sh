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

# ─── QMI WWAN 驱动内核版本兼容修复 ──────────────────────
#
# 问题：fibocom_QMI_WWAN / quectel_QMI_WWAN 是 lede 内置包，
#       源文件在 package/wwan/driver/XXX/src/ 下，
#       同一份 C 代码会被不同内核版本编译：
#         WH3000/Pro → Linux 6.18（hrtimer_init 已删除，必须用 hrtimer_setup）
#         RE-SP-01B  → Linux 5.10（hrtimer_setup 尚未存在，必须用 hrtimer_init）
#
# 修复方案：用 #if LINUX_VERSION_CODE 条件编译，让同一份源码同时兼容两个内核
#   >= 6.17：hrtimer_setup(&timer, cb, clock, mode)  ← 一步完成
#   <  6.17：hrtimer_init(&timer, clock, mode)        ← 分两步，保留 .function=cb 行
#
# 同修：qma_setting_store 缺 static 前置声明（-Werror=missing-prototypes）

echo ">>> 修复 QMI WWAN 驱动多内核兼容性..."

python3 << 'PYEOF'
import re, os, sys

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

    # 已修复过（含版本条件），幂等跳过
    if 'KERNEL_VERSION(6, 17, 0)' in src:
        print(f'  [OK]   已含版本条件，无需重复修复: {fname}')
        return

    # 必须含 hrtimer_init 才需要处理
    if 'hrtimer_init' not in src:
        print(f'  [OK]   无 hrtimer_init，无需修复: {fname}')
        return

    # 提取回调函数名（不硬编码，兼容将来版本更新）
    m = re.search(r'agg_hrtimer\.function\s*=\s*(\w+)\s*;', src)
    if not m:
        print(f'  [WARN] 找不到 .function= 赋值，跳过: {fname}')
        return
    cb = m.group(1)
    print(f'  callback={cb}')

    # ── 1. 确保 linux/version.h 已引入 ─────────────────────────────────────
    if '#include <linux/version.h>' not in src:
        # 插入到第一个 #include 之前
        src = re.sub(
            r'^(#include\s)',
            r'#include <linux/version.h>\n\1',
            src, count=1, flags=re.MULTILINE
        )

    # ── 2. 把 hrtimer_init 行替换成版本条件块 ─────────────────────────────
    #  原行（任意缩进）：
    #    \thrtimer_init(&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    #  替换为：
    #    \t#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 17, 0)
    #    \t\thrtimer_setup(&priv->agg_hrtimer, cb, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    #    \t#else
    #    \t\thrtimer_init(&priv->agg_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    #    \t#endif
    #  ──────────────────────────────────────────────────────────────────────
    #  注意：.function=cb 行保持原位不动
    #    ·  对 Linux < 6.17：hrtimer_init 不改变 .function，.function=cb 生效
    #    ·  对 Linux >= 6.17：hrtimer_setup 内部已设置 .function，.function=cb
    #       行是冗余赋值（同值覆盖），无害

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
        repl,
        src,
        flags=re.MULTILINE
    )

    if n == 0:
        print(f'  [WARN] hrtimer_init 行未被替换，请检查源码格式: {fname}')
        return
    print(f'  hrtimer 条件块替换: {n} 处')

    # ── 3. qma_setting_store 缺 static（仅 qmi_wwan_f.c）──────────────────
    if fname == 'qmi_wwan_f.c':
        src, n3 = re.subn(
            r'^int\s+qma_setting_store\s*\(',
            'static int qma_setting_store(',
            src, flags=re.MULTILINE
        )
        if n3:
            print(f'  qma_setting_store → static: {n3} 处')

    # ── 写回 ───────────────────────────────────────────────────────────────
    if src != orig:
        open(fpath, 'w', encoding='utf-8').write(src)
        print(f'  ✓ 写入完成: {fpath}')
    else:
        print(f'  [WARN] 内容无变化: {fpath}')

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
