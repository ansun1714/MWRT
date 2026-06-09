#!/bin/bash

echo "========================================"
echo " DIY Part 1 - 配置软件源"
echo "========================================"

# ── 添加自定义 Feeds ─────────────────────────
echo "src-git lucky https://github.com/gdy666/luci-app-lucky.git" \
    >> feeds.conf.default
echo "src-git qmodem https://github.com/FUjr/modem_feeds.git;main" \
    >> feeds.conf.default
echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git" \
    >> feeds.conf.default

# ── 克隆 msd_lite ────────────────────────────
git clone --depth=1 \
    https://github.com/ximiTech/msd_lite \
    package/msd_lite
rm -f package/msd_lite/files/etc/init.d/msd_lite 2>/dev/null || true

# ── 复制自定义 LuCI 插件 ─────────────────────
cp -r "${GITHUB_WORKSPACE}/custom-packages/luci-app-iptv-manager" \
    package/luci-app-iptv-manager

# ════════════════════════════════════════════════════════════════
#  清理 backport-6.6 冲突 patches（综合内容扫描，全层级覆盖）
#
#  问题根源：LEDE 将 net/phy 驱动系统性迁移到子目录（6.7~6.16 的变更）：
#    aquantia → drivers/net/phy/aquantia/  (Linux 6.7)
#    at803x   → drivers/net/phy/qcom/     (Linux 6.9)
#    realtek  → drivers/net/phy/realtek/  (Linux 6.14)
#    Aeonsemi/其他新 PHY 芯片...           (陆续增加)
#
#  每次迁移形成 patch 依赖链：
#    "移目录" patch → 修改顶层 Kconfig/Makefile（已被扫描删除）
#    后续 patch     → 修改子目录内的文件（因目录不存在而报错）
#
#  扫描策略（三重条件，任意命中即删除）：
#    1. 引用已知 PHY 子目录路径（aquantia/ qcom/ realtek/）
#    2. 引用 at803x 路径
#    3. 修改了 drivers/net/phy/ 下任意层级的 Kconfig 或 Makefile
#       ★ 改进：.* 匹配任意子目录，覆盖 realtek/Kconfig 等子目录文件
#
#  安全性：WH3000/WH3000 Pro 使用 MT7981 + MT7531（均为 MediaTek），
#           不依赖 Realtek RTL8xxx / Aquantia / QCOM / at803x / Aeonsemi
#           等第三方 PHY 芯片，删除全部无影响。
# ════════════════════════════════════════════════════════════════
BKPORT_DIR="target/linux/generic/backport-6.6"
if [ -d "$BKPORT_DIR" ]; then
    echo ">>> 扫描 backport-6.6 冲突 patches（全层级内容扫描）..."
    REMOVED=0
    for f in "$BKPORT_DIR"/*.patch; do
        [ -f "$f" ] || continue
        # 三重扫描条件（任意一条命中 → 删除）
        if grep -qE \
            'drivers/net/phy/(aquantia|qcom|realtek)/|net/phy/at803x|\+\+\+ b/drivers/net/phy/.*(Kconfig|Makefile)' \
            "$f" 2>/dev/null; then
            rm -f "$f"
            echo "  🗑️  $(basename "$f")"
            REMOVED=$((REMOVED + 1))
        fi
    done
    if [ "$REMOVED" -eq 0 ]; then
        echo "  ℹ️  无冲突 patch，跳过"
    else
        echo "  ✅ 共清理 $REMOVED 个冲突 patch"
    fi
fi

# ════════════════════════════════════════════════════════════════
#  修复 gpio-button-hotplug 上游 API 兼容性
#  （#ifndef 保护，内核原生支持时自动跳过）
# ════════════════════════════════════════════════════════════════
GHBH_C="package/kernel/gpio-button-hotplug/src/gpio-button-hotplug.c"

if [ -f "$GHBH_C" ]; then
    echo ">>> 修复 gpio-button-hotplug 内核兼容性..."

    python3 << 'PYEOF'
import re

filepath = 'package/kernel/gpio-button-hotplug/src/gpio-button-hotplug.c'
with open(filepath, 'r') as f:
    content = f.read()

changed = False
shims = []

# Shim 1: devm_kmemdup_array (Linux >= 6.8)
if 'devm_kmemdup_array' in content and '__compat_devm_kmemdup_array' not in content:
    shims.append(
        '/* COMPAT: devm_kmemdup_array (Linux >= 6.8; #ifndef auto-skip on 6.8+) */\n'
        '#ifndef devm_kmemdup_array\n'
        '#include <linux/string.h>\n'
        'static inline void *__compat_devm_kmemdup_array(\n'
        '    struct device *dev, const void *src,\n'
        '    size_t n, size_t size, gfp_t gfp)\n'
        '{\n'
        '    void *p = devm_kmalloc_array(dev, n, size, gfp);\n'
        '    if (p) memcpy(p, src, n * size);\n'
        '    return p;\n'
        '}\n'
        '#define devm_kmemdup_array(dev, src, n, size, gfp) \\\n'
        '    __compat_devm_kmemdup_array(dev, src, n, size, gfp)\n'
        '#endif'
    )
    changed = True
    print('  OK: devm_kmemdup_array shim 已添加')

# Shim 2: for_each_available_child_of_node_scoped (Linux >= 6.5)
if ('for_each_available_child_of_node_scoped' in content and
        'compat_node_scoped' not in content):
    shims.append(
        '/* COMPAT: for_each_available_child_of_node_scoped (Linux >= 6.5)\n'
        ' * Linux 6.6 has natively; #ifndef auto-skips */\n'
        '#ifndef for_each_available_child_of_node_scoped\n'
        '#define for_each_available_child_of_node_scoped(parent, child) \\\n'
        '    for (struct device_node *(child) = \\\n'
        '             of_get_next_available_child((parent), NULL); \\\n'
        '         (child) != NULL; \\\n'
        '         (child) = of_get_next_available_child((parent), (child)))\n'
        '#endif'
    )
    changed = True
    print('  OK: for_each_available_child_of_node_scoped shim 已添加')

if shims:
    combined = '\n\n' + '\n\n'.join(shims) + '\n\n'
    includes = list(re.finditer(r'^#include\s+.*$', content, re.MULTILINE))
    if includes:
        pos = includes[-1].end()
        content = content[:pos] + combined + content[pos:]
    else:
        content = combined + content

# Fix 3: void .remove → int .remove (Linux >= 6.11 changed to void)
lines = content.split('\n')
result = []
in_remove = False
depth = 0

for line in lines:
    if (not in_remove
            and 'static void ' in line
            and '_remove(' in line
            and 'platform_device' in line):
        line = line.replace('static void ', 'static int ', 1)
        in_remove = True
        depth = 0
        changed = True

    if in_remove:
        prev = depth
        depth += line.count('{') - line.count('}')
        if prev > 0 and depth == 0 and '}' in line:
            result.append('\treturn 0;')
            in_remove = False

    result.append(line)

content = '\n'.join(result)

if changed:
    with open(filepath, 'w') as f:
        f.write(content)
    print('  OK: gpio-button-hotplug 全部 patch 完成')
else:
    print('  INFO: 文件无需修复')
PYEOF

else
    echo ">>> gpio-button-hotplug 不存在，跳过"
fi

echo "========================================"
echo " DIY Part 1 完成"
echo "========================================"
cat feeds.conf.default
