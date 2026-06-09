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
#  通用设置（所有设备共享）
# ════════════════════════════════════════════

# ── 1. 主机名（以型号命名）─────────────────
case "$DEVICE" in
  wh3000)    HOSTNAME="WH3000"     ;;
  wh3000pro) HOSTNAME="WH3000-Pro" ;;
  re-sp-01b) HOSTNAME="RE-SP-01B"  ;;
  *)         HOSTNAME="DONGZAI"    ;;
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

	config_get type       "config" "type"        "0"
	config_get port       "config" "port"         "7088"
	config_get source     "config" "source"       "eth0"
	config_get threads    "config" "threads"      "0"
	config_get buffer     "config" "buffer"       "16384"
	config_get rejointime "config" "rejointime"   "0"

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
#  设备专属设置
# ════════════════════════════════════════════

case "$DEVICE" in

  # ──────────────────────────────────────────
  #  WH3000 / WH3000 Pro（MT7981 ARM Filogic）
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

 ____   ___  _   _  ____ _____    _    ___ 
|  _ \ / _ \| \ | |/ ___|__  /  / \  |_ _|
| | | | | | |  \| | |  _ / /  / _ \  | | 
| |_| | |_| | |\  | |_| |/ /__/ ___ \ | | 
|____/ \___/|_| \_|\____/____/_/   \_\___|

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
  #  RE-SP-01B（MT7621 MIPS · 512MB RAM）
  #  WiFi: MT7603E(PCIe0) + 5G(PCIe1)
  #  启动日志确认路径：
  #    2.4G: pci0000:01/0000:01:00.0 [14c3:7603]
  #    5G:   pci0000:02/0000:02:00.0
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
    # 根因：MT7621 上 uci-defaults 运行时 WiFi 驱动尚未完全初始化
    # 修法：通过 rc.local 在所有服务就绪后延迟执行 wifi up
    # （移除 uci-defaults 方式，改用 rc.local 更可靠）
    cat > files/etc/rc.local << 'EOF'
#!/bin/sh
# RE-SP-01B WiFi 首启修复
# MT7621 首次启动时驱动初始化较慢，延迟 8 秒确保 wifi up 时驱动已就绪
sleep 8 && wifi up >/dev/null 2>&1
exit 0
EOF
    chmod +x files/etc/rc.local
    echo ">>> [5] WiFi 首启修复完成（rc.local 延迟启动）"

    
    # Banner
    cat > files/etc/banner << 'EOF'

 ____   ___  _   _  ____ _____    _    ___ 
|  _ \ / _ \| \ | |/ ___|__  /  / \  |_ _|
| | | | | | |  \| | |  _ / /  / _ \  | | 
| |_| | |_| | |\  | |_| |/ /__/ ___ \ | | 
|____/ \___/|_| \_|\____/____/_/   \_\___|

    DONGZAI 固件工厂 · JDCloud RE-SP-01B
    Platform: MediaTek MT7621 · MIPS · 512MB

EOF

    echo "========================================"
    echo " RE-SP-01B 配置完成"
    echo " 主机名    : RE-SP-01B"
    echo " WiFi 2.4G : RE-SP-01B    (开放，刷机后设密码)"
    echo " WiFi 5G   : RE-SP-01B_5G (开放，刷机后设密码)"
    echo " Docker    : /mnt/mmcblk0p1/docker"
    echo " 注意      : eMMC 分区号如有误，在 LuCI 挂载点调整"
    echo "========================================"
    ;;

esac

echo "========================================"
echo " DIY Part 2 全部完成 · DONGZAI 固件工厂"
echo "========================================"
