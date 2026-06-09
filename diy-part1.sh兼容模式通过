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
#  修复 gpio-button-hotplug 上游兼容性问题
#  根因：LEDE 上游更新该包使用了 Linux 6.8 / 6.11 新 API：
#    1. devm_kmemdup_array  → Linux >= 6.8，我们的内核：5.10 / 6.6
#    2. void .remove 回调   → Linux >= 6.11，5.10 / 6.6 必须返回 int
#  影响：所有设备（ARM Filogic + MIPS MT7621）全部编译失败
#  修法：在编译前自动 patch 源文件，添加兼容层
# ════════════════════════════════════════════════════════════════
GHBH_C="package/kernel/gpio-button-hotplug/src/gpio-button-hotplug.c"

if [ -f "$GHBH_C" ]; then
    echo ">>> 检测 gpio-button-hotplug 兼容性..."

    python3 << 'PYEOF'
import re

filepath = 'package/kernel/gpio-button-hotplug/src/gpio-button-hotplug.c'
with open(filepath, 'r') as f:
    content = f.read()

changed = False

# ── Fix 1: devm_kmemdup_array 兼容层 ──────────────────────────
# 该函数 Linux >= 6.8 才有，在此之前用 devm_kmalloc_array + memcpy 替代
if 'devm_kmemdup_array' in content and '__compat_devm_kmemdup_array' not in content:
    shim = (
        '\n'
        '/* COMPAT: devm_kmemdup_array was added in Linux 6.8\n'
        ' * Provide fallback for kernels 5.x and 6.6 */\n'
        '#ifndef devm_kmemdup_array\n'
        '#include <linux/string.h>\n'
        'static inline void *__compat_devm_kmemdup_array(\n'
        '    struct device *dev, const void *src,\n'
        '    size_t n, size_t size, gfp_t gfp)\n'
        '{\n'
        '    void *p = devm_kmalloc_array(dev, n, size, gfp);\n'
        '    if (p)\n'
        '        memcpy(p, src, n * size);\n'
        '    return p;\n'
        '}\n'
        '#define devm_kmemdup_array(dev, src, n, size, gfp) \\\n'
        '    __compat_devm_kmemdup_array(dev, src, n, size, gfp)\n'
        '#endif\n\n'
    )
    # 插入到最后一个 #include 之后
    includes = list(re.finditer(r'^#include\s+.*$', content, re.MULTILINE))
    if includes:
        pos = includes[-1].end()
        content = content[:pos] + '\n' + shim + content[pos:]
    else:
        content = shim + content
    changed = True
    print('  OK: devm_kmemdup_array 兼容层已添加')

# ── Fix 2: void .remove → int .remove ─────────────────────────
# Linux 6.11 将 platform_driver.remove 改为返回 void
# 我们的内核 (5.10, 6.6) 仍要求返回 int
lines = content.split('\n')
result = []
in_remove = False
depth = 0

for line in lines:
    # 匹配 static void xxx_remove 函数定义行
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
        # 检测函数体的最外层闭合花括号
        if prev > 0 and depth == 0 and '}' in line:
            result.append('\treturn 0;')
            in_remove = False

    result.append(line)

content = '\n'.join(result)

if changed:
    with open(filepath, 'w') as f:
        f.write(content)
    print('  OK: gpio-button-hotplug patch 成功')
else:
    print('  INFO: 文件无需修复（可能已是兼容版本）')
PYEOF

else
    echo ">>> gpio-button-hotplug 源文件不存在，跳过"
fi

echo "========================================"
echo " DIY Part 1 完成"
echo "========================================"
cat feeds.conf.default
