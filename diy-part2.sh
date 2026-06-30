#!/bin/bash

DEVICE="${DEVICE:-wh3000pro}"

echo "========================================"
echo " DONGZAI 固件工厂 - DIY Part 2"
echo " 当前设备：$DEVICE"
echo "========================================"

mkdir -p files/etc/uci-defaults
mkdir -p files/etc/config
mkdir -p files/etc/init.d

# ════════════════════════════════════════════
# 通用设置（所有设备共享）
# ════════════════════════════════════════════

# ── 1. 主机名（以型号命名）─────────────────
case "$DEVICE" in
  wh3000)    HOSTNAME="WH3000" ;;
  wh3000pro) HOSTNAME="WH3000-Pro" ;;
  re-sp-01b) HOSTNAME="RE-SP-01B" ;;
  *)         HOSTNAME="MWRT" ;;
esac

cat > files/etc/uci-defaults/01-system << EOF
#!/bin/sh
uci set system.@system[0].hostname='${HOSTNAME}'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci commit system
exit 0
EOF
chmod +x files/etc/uci-defaults/01-system
echo ">>> [1] 主机名：${HOSTNAME}"

# ── 2. 默认主题 ─────────────────────────────
sed -i 's/luci-theme-bootstrap/luci-theme-design/g' \
  package/lean/default-settings/files/zzz-default-settings 2>/dev/null
echo ">>> [2] 默认主题修改完成"

# ── 3. Lucky 权限 ────────────────────────────
find . -type f -name "lucky*" -exec chmod +x {} \; 2>/dev/null
echo ">>> [3] Lucky 权限修复完成"

# ── 8. 系统网络优化 ──────────────────────────
cat > files/etc/sysctl.conf << 'EOF'
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
EOF
echo ">>> [8] sysctl 优化完成"

# ── 9-1. msd_lite 默认 UCI 配置 ─────────────
cat > files/etc/config/msd_lite << 'EOF'
config msd_lite 'config'
	option enable '0'
	option type '0'
	option source 'eth0'
	option port '7088'
	option threads '0'
	option buffer '16384'
	option rejointime '0'
EOF
echo ">>> [9-1] msd_lite UCI 配置写入完成"

# ── 9-2. msd_lite 双后端 init.d ──────────────
cat > files/etc/init.d/msd_lite << 'INITEOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    local enable type port source threads buffer rejointime PROG
    config_load "msd_lite"
    config_get_bool enable "config" "enable" "0"
    [ "$enable" -eq "1" ] || return 0
    config_get type       "config" "type"       "0"
    config_get port       "config" "port"       "7088"
    config_get source     "config" "source"     "eth0"
    config_get threads    "config" "threads"    "0"
    config_get buffer     "config" "buffer"     "16384"
    config_get rejointime "config" "rejointime" "0"
    mkdir -p /var/etc
    if [ "$type" = "0" ]; then
        PROG="/usr/bin/msd_lite"
        cat > /var/etc/msd_lite.conf << XMLEOF
<?xml version="1.0" encoding="utf-8"?>
<msd>
  <log><file>/var/log/msd_lite.log</file></log>
  <threadPool>
    <threadsCountMax>${threads}</threadsCountMax>
    <fBindToCPU>yes</fBindToCPU>
  </threadPool>
  <HTTP>
    <bindList>
      <bind><address>0.0.0.0:${port}</address></bind>
      <bind><address>[::]:${port}</address></bind>
    </bindList>
    <hostnameList><hostname>*</hostname></hostnameList>
  </HTTP>
  <hubProfileList>
    <hubProfile>
      <fDropSlowClients>no</fDropSlowClients>
      <fSocketTCPNoDelay>yes</fSocketTCPNoDelay>
      <precache>${buffer}</precache>
      <ringBufSize>1024</ringBufSize>
      <headersList>
        <header>Pragma: no-cache</header>
        <header>Content-Type: video/mpeg</header>
      </headersList>
    </hubProfile>
  </hubProfileList>
  <sourceProfileList>
    <sourceProfile>
      <skt>
        <rcvBuf>512</rcvBuf>
        <rcvTimeout>2</rcvTimeout>
      </skt>
      <multicast>
        <ifName>${source}</ifName>
        <rejoinTime>${rejointime}</rejoinTime>
      </multicast>
    </sourceProfile>
  </sourceProfileList>
</msd>
XMLEOF
    else
        PROG="/usr/bin/rtp2httpd"
        cat > /var/etc/msd_lite.conf << RTPEOF
[global]
verbosity = 3
upstream-interface = ${source}
workers = ${threads}
buffer-pool-max-size = ${buffer}
mcast-rejoin-interval = ${rejointime}
zerocopy-on-send = yes

[bind]
* ${port}
RTPEOF
    fi
    procd_open_instance
    procd_set_param command "$PROG" -c /var/etc/msd_lite.conf
    procd_set_param respawn
    procd_set_param stderr 1
    procd_close_instance
}

reload_service() {
    stop
    start
}

service_triggers() {
    procd_add_reload_trigger "msd_lite"
}
INITEOF
chmod +x files/etc/init.d/msd_lite
echo ">>> [9-2] msd_lite 双后端 init.d 写入完成"

# ════════════════════════════════════════════
# 设备专属设置
# ════════════════════════════════════════════

case "$DEVICE" in

# ──────────────────────────────────────────
# WH3000 / WH3000 Pro（MT7981 ARM Filogic）
# ──────────────────────────────────────────
wh3000|wh3000pro)
    echo ">>> 应用 WH3000/WH3000 Pro 专属配置..."

    # 4. WiFi 预配置（MT7981 Filogic 专用路径）
    cat > files/etc/config/wireless << 'EOF'
config wifi-device 'radio0'
	option type 'mac80211'
	option path 'platform/soc/18000000.wifi'
	option band '2g'
	option channel 'auto'
	option htmode 'HT40'
	option country 'CN'
	option cell_density '0'
	option disabled '0'

config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid 'Camera_mao'
	option encryption 'psk2'
	option key '18921500010'

config wifi-device 'radio1'
	option type 'mac80211'
	option path 'platform/soc/18000000.wifi+1'
	option band '5g'
	option channel '36'
	option htmode 'HE80'
	option country 'CN'
	option cell_density '0'
	option disabled '0'

config wifi-iface 'default_radio1'
	option device 'radio1'
	option network 'lan'
	option mode 'ap'
	option ssid '栋仔_5G'
	option encryption 'psk2'
	option key '18851575507'
EOF
    echo ">>> [4] WH3000 Pro WiFi 预配置完成"

    # 5. WiFi 首启优化
    cat > files/etc/uci-defaults/99-wifi-fast << 'EOF'
#!/bin/sh
rm -f /etc/uci-defaults/network
rm -f /etc/uci-defaults/wireless
wifi reload >/dev/null 2>&1
exit 0
EOF
    chmod +x files/etc/uci-defaults/99-wifi-fast
    echo ">>> [5] WiFi 首启优化完成"

    # 6. Docker 数据目录（WH3000 Pro eMMC 专用分区）
    cat > files/etc/config/fstab << 'EOF'
config global
	option anon_mount '1'
	option auto_mount '1'
	option auto_swap '1'

config mount
	option target '/mnt/mmcblk0p7'
	option device '/dev/mmcblk0p7'
	option fstype 'ext4'
	option options 'rw,sync,noatime'
	option enabled '1'
EOF

    cat > files/etc/uci-defaults/30-docker << 'EOF'
#!/bin/sh
mkdir -p /mnt/mmcblk0p7/docker
uci set dockerd.globals.data_root='/mnt/mmcblk0p7/docker'
uci commit dockerd
/etc/init.d/dockerd enable
/etc/init.d/dockerd restart
exit 0
EOF
    chmod +x files/etc/uci-defaults/30-docker
    echo ">>> [6] Docker 数据目录配置完成（/mnt/mmcblk0p7）"

    # Banner
    cat > files/etc/banner << 'EOF'
 ____   ___  _ _  ____ _____ _      ___
|  _ \ / _ \| \ | |/ ___|__ / / \  |_ _|
| | | | | | | \| | |  _ / / / _ \  | |
| |_| | |_| | |\ | |_| |/ /__/ ___ \ | |
|____/ \___/|_| \_|\____/____/_/ \_\___|

DONGZAI 固件工厂 · Huasifei WH3000 Pro
Platform: MediaTek MT7981 · ARM · 512MB
EOF

    echo "========================================"
    echo " WH3000 Pro 配置完成"
    echo " 主机名    : WH3000-Pro"
    echo " WiFi 2.4G : Camera_mao"
    echo " WiFi 5G   : 栋仔_5G"
    echo " Docker    : /mnt/mmcblk0p7/docker"
    echo "========================================"
    ;;

# ──────────────────────────────────────────
# RE-SP-01B（MT7621 MIPS · 512MB RAM）
# ──────────────────────────────────────────
re-sp-01b)
    echo ">>> 应用 RE-SP-01B 专属配置..."

    # 4. WiFi 预配置（MT7621 PCI 路径）
    cat > files/etc/config/wireless << 'EOF'
config wifi-device 'radio0'
	option type 'mac80211'
	option path 'pci0000:01/0000:01:00.0'
	option band '2g'
	option channel 'auto'
	option htmode 'HT40'
	option country 'CN'
	option disabled '0'

config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid 'RE-SP-01B'
	option encryption 'none'

config wifi-device 'radio1'
	option type 'mac80211'
	option path 'pci0000:02/0000:02:00.0'
	option band '5g'
	option channel '36'
	option htmode 'VHT80'
	option country 'CN'
	option disabled '0'

config wifi-iface 'default_radio1'
	option device 'radio1'
	option network 'lan'
	option mode 'ap'
	option ssid 'RE-SP-01B_5G'
	option encryption 'none'
EOF
    echo ">>> [4] RE-SP-01B WiFi 预配置完成"

    # 5. WiFi 首启修复
    cat > files/etc/rc.local << 'EOF'
#!/bin/sh
sleep 8 && wifi up >/dev/null 2>&1
exit 0
EOF
    chmod +x files/etc/rc.local
    echo ">>> [5] WiFi 首启修复完成"

    # Banner
    cat > files/etc/banner << 'EOF'
 ____   ___  _ _  ____ _____ _      ___
|  _ \ / _ \| \ | |/ ___|__ / / \  |_ _|
| | | | | | | \| | |  _ / / / _ \  | |
| |_| | |_| | |\ | |_| |/ /__/ ___ \ | |
|____/ \___/|_| \_|\____/____/_/ \_\___|

DONGZAI 固件工厂 · JDCloud RE-SP-01B
Platform: MediaTek MT7621 · MIPS · 512MB
EOF

    echo "========================================"
    echo " RE-SP-01B 配置完成"
    echo " 主机名    : RE-SP-01B"
    echo " WiFi 2.4G : RE-SP-01B"
    echo " WiFi 5G   : RE-SP-01B_5G"
    echo "========================================"
    ;;

esac

# ════════════════════════════════════════════
# 【修复】QMI WWAN 驱动 Linux 6.17+ 内核兼容
#
# 根因：Linux 6.17 彻底移除了 hrtimer_init()，改用 hrtimer_setup()
#   旧写法（Fibocom 顺序）：.function=cb → hrtimer_init(timer,clock,mode)
#   旧写法（Quectel 顺序）：hrtimer_init(timer,clock,mode) → .function=cb
#   新写法（统一）        ：hrtimer_setup(timer,cb,clock,mode)
#
# 为何之前的脚本无效：
#   1. 路径写死了 /src/ 子目录，而源文件实际在包目录根层
#   2. 正则试图同时匹配两行，但两驱动的顺序相反导致匹配失败
#
# 本版本修复策略：
#   - os.walk 动态搜索（不依赖路径假设）
#   - 两步分离：先替换 hrtimer_init，再删 .function= 行（顺序无关）
#   - 搜索范围：feeds/ 目录（原始文件，symlink 前的真实位置）
# ════════════════════════════════════════════

echo ">>> [10] QMI WWAN 驱动内核兼容修复..."

python3 << 'PYEOF'
import os, re

TARGET = {'qmi_wwan_f.c', 'qmi_wwan_q.c'}
SKIP   = {'.git', 'patches'}
seen   = set()

def fix(path):
    fname = os.path.basename(path)
    try:
        src = open(path, encoding='utf-8', errors='replace').read()
    except OSError as e:
        print(f'  [ERR] 读取失败: {e}'); return

    if 'hrtimer_init' not in src:
        print(f'  [OK]  无需修复（已无 hrtimer_init）'); return

    # 提取回调函数名（不假设它在 hrtimer_init 之前还是之后）
    m = re.search(r'agg_hrtimer\.function\s*=\s*(\w+)\s*;', src)
    if not m:
        print(f'  [WARN] 找不到 agg_hrtimer.function 赋值，跳过'); return
    cb = m.group(1)
    print(f'  回调函数: {cb}')

    orig = src

    # 步骤1：替换 hrtimer_init → hrtimer_setup
    src, n1 = re.subn(
        r'hrtimer_init\s*\(\s*&\s*priv\s*->\s*agg_hrtimer\s*,'
        r'\s*CLOCK_MONOTONIC\s*,\s*HRTIMER_MODE_REL\s*\)\s*;',
        f'hrtimer_setup(&priv->agg_hrtimer, {cb}, CLOCK_MONOTONIC, HRTIMER_MODE_REL);',
        src
    )
    print(f'  hrtimer_init 替换: {n1} 处')

    # 步骤2：删除现在多余的 .function = cb 那整行
    src, n2 = re.subn(
        r'[ \t]*priv\s*->\s*agg_hrtimer\.function\s*=\s*'
        + re.escape(cb) + r'\s*;\n',
        '',
        src
    )
    print(f'  .function 赋值行删除: {n2} 行')

    # 步骤3：qma_setting_store 缺前置声明 → 加 static（仅 qmi_wwan_f.c）
    if fname == 'qmi_wwan_f.c':
        src, n3 = re.subn(
            r'^int\s+qma_setting_store\s*\(',
            'static int qma_setting_store(',
            src, flags=re.MULTILINE
        )
        if n3: print(f'  qma_setting_store → static: {n3} 处')

    if src == orig:
        print(f'  [WARN] 内容无变化，可能正则未命中，请检查源文件格式')
        return

    open(path, 'w', encoding='utf-8').write(src)
    print(f'  ✓ 修复完成')

# 打印工作目录方便排查
print(f'CWD: {os.getcwd()}')

# 从 feeds/ 目录搜索（原始文件位置，不依赖 symlink 结构）
if not os.path.isdir('feeds'):
    print('[CRITICAL] feeds/ 目录不存在！请确认在 feeds update/install 之后运行本脚本。')
else:
    for root, dirs, files in os.walk('feeds', followlinks=True):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for fname in files:
            if fname not in TARGET:
                continue
            path = os.path.join(root, fname)
            real = os.path.realpath(path)
            if real in seen:
                continue
            seen.add(real)
            print(f'\n[文件] {path}')
            fix(path)

    if not seen:
        print('\n[CRITICAL] feeds/ 中未找到任何目标文件！')
        print('目录结构预览（用于诊断）:')
        for root, dirs, files in os.walk('feeds', followlinks=True):
            dirs[:] = [d for d in dirs if d not in SKIP]
            depth = root.count(os.sep)
            if depth > 5: continue
            print(f'  {"  " * depth}{os.path.basename(root)}/')
            for f in files:
                print(f'  {"  " * (depth+1)}{f}')
PYEOF

echo ">>> [10] 修复脚本执行完毕"

echo "========================================"
echo " DIY Part 2 全部完成 · DONGZAI 固件工厂"
echo "========================================"

