#!/bin/bash

DEVICE="${DEVICE:-wh3000pro}"

echo "========================================"
echo " DONGZAI 固件工厂 - DIY Part 2"
echo " 当前设备：$DEVICE"
echo "========================================"

mkdir -p files/etc/uci-defaults files/etc/config files/etc/init.d

# ════════════════════════════════════════════════════════════
# ovpn-dco：与 Linux 6.18.49+ 不兼容，直接移除
# ════════════════════════════════════════════════════════════

echo ">>> [ovpn-dco] 关闭 OpenVPN DCO..."

for f in feeds/packages/net/openvpn/Config-*.in; do
  [ -f "$f" ] || continue
  sed -i '/ENABLE_DCO/,+8 s/default y.*/default n/' "$f"
done

if [ -f feeds/packages/net/openvpn/Makefile ]; then
  sed -i \
    -e 's/+OPENVPN_$(1)_ENABLE_DCO:kmod-ovpn-dco-v2//' \
    -e 's/+OPENVPN_$(1)_ENABLE_DCO:kmod-ovpn-backports//' \
    -e 's/+OPENVPN_$(1)_ENABLE_DCO:kmod-ovpn-dco//' \
    feeds/packages/net/openvpn/Makefile
fi

rm -rf feeds/packages/kernel/ovpn-dco
rm -rf package/feeds/packages/ovpn-dco

sed -i \
  -e '/^CONFIG_PACKAGE_kmod-ovpn/d' \
  -e '/^CONFIG_OPENVPN_.*ENABLE_DCO=/d' \
  .config

cat >> .config << 'EOF'
CONFIG_PACKAGE_kmod-crypto-hash=y
CONFIG_PACKAGE_kmod-crypto-aead=y
CONFIG_PACKAGE_kmod-crypto-manager=y
CONFIG_PACKAGE_kmod-crypto-chacha20poly1305=y
# CONFIG_PACKAGE_kmod-ovpn-dco is not set
# CONFIG_PACKAGE_kmod-ovpn-dco-v2 is not set
# CONFIG_PACKAGE_kmod-ovpn-backports is not set
# CONFIG_OPENVPN_openssl_ENABLE_DCO is not set
EOF

echo ">>> [ovpn-dco] 完成"

# ════════════════════════════════════════════════════════════
# 通用设置（所有设备共享）
# ════════════════════════════════════════════════════════════

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

sed -i 's/luci-theme-bootstrap/luci-theme-design/g' \
  package/lean/default-settings/files/zzz-default-settings 2>/dev/null
echo ">>> [2] 默认主题修改完成"

find . -type f -name "lucky*" -exec chmod +x {} \; 2>/dev/null
echo ">>> [3] Lucky 权限修复完成"

# ════════════════════════════════════════════════════════════
# ★ Fix-songloft：修复 songloft 启动脚本 UCI 校验错误
# 根因：原脚本把 section_id 当成了回调函数，导致启动报错
# 方案：直接在 files/ 覆盖正确的启动脚本，随固件打包
# ════════════════════════════════════════════════════════════
echo ">>> [3.5] 修复 songloft 启动脚本..."
cat > files/etc/init.d/songloft << 'EOF'
#!/bin/sh /etc/rc.common
# SPDX-License-Identifier: GPL-2.0-only

START=99
STOP=10
USE_PROCD=1

PROG_DEFAULT=/usr/bin/songloft
WEB_DEFAULT=/usr/share/songloft/web-embedded

LOGGER="logger -t songloft"

validate_songloft_section() {
    uci_load_validate songloft "$1" "$2" \
    'enabled:bool:0' \
    'listen_port:port:58091' \
    'db_path:string:/etc/songloft/data' \
    'base_path:string' \
    'admin_username:string' \
    'admin_password:string' \
    'bin_path:string' \
    'web_path:string'
}

start_instance() {
    local cfg="$1"
    local result="$2"
    [ "$result" = "0" ] || {
        ${LOGGER} "配置校验失败，section=$cfg"
        return 1
    }
    [ "$enabled" = "1" ] || return 0

    local bin="${bin_path:-$PROG_DEFAULT}"
    local web="${web_path:-$WEB_DEFAULT}"

    if [ ! -x "$bin" ]; then
        ${LOGGER} "未找到可执行文件: $bin"
        return 1
    fi
    mkdir -p "$db_path"

    procd_open_instance "songloft.$cfg"
    procd_set_param command "$bin"
    procd_set_param env LISTEN_PORT="$listen_port"
    [ -n "$base_path" ] && \
        procd_append_param env BASE_PATH="$base_path"
    [ -n "$admin_username" ] && \
        procd_append_param env ADMIN_USERNAME="$admin_username"
    [ -n "$admin_password" ] && \
        procd_append_param env ADMIN_PASSWORD="$admin_password"
    [ -d "$web" ] && \
        procd_append_param env WEB_ROOT="$web"
    procd_set_param cwd "$db_path"
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

start_service() {
    config_load songloft
    config_foreach validate_songloft_section songloft start_instance
}

stop_service() {
    :
}

service_triggers() {
    procd_add_reload_trigger "songloft"
}

reload_service() {
    stop
    start
}
EOF
chmod +x files/etc/init.d/songloft
echo ">>> [3.5] songloft 启动脚本修复完成"

cat > files/etc/sysctl.conf << 'EOF'
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
EOF
echo ">>> [8] sysctl 优化完成"

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

reload_service() { stop; start; }
service_triggers() { procd_add_reload_trigger "msd_lite"; }
INITEOF
chmod +x files/etc/init.d/msd_lite
echo ">>> [9-2] msd_lite 双后端 init.d 写入完成"

# ════════════════════════════════════════════════════════════
# 设备专属设置
# ════════════════════════════════════════════════════════════

case "$DEVICE" in

# ──────────────────────────────────────────
# WH3000 / WH3000 Pro（MT7981 ARM Filogic）
# ──────────────────────────────────────────
wh3000|wh3000pro)
    echo ">>> 应用 WH3000/WH3000 Pro 专属配置..."

    echo ">>> [WiFi-Fix] 补充缺失的 netifd-wireless.sh..."
    mkdir -p files/lib/netifd

    curl -fsSL --retry 3 \
        "https://raw.githubusercontent.com/openwrt/openwrt/v24.10.5/package/network/config/wifi-scripts/files/lib/netifd/netifd-wireless.sh" \
        -o files/lib/netifd/netifd-wireless.sh

    if [ -s files/lib/netifd/netifd-wireless.sh ]; then
        chmod 755 files/lib/netifd/netifd-wireless.sh
        echo "  ✓ netifd-wireless.sh 已下载（$(wc -c < files/lib/netifd/netifd-wireless.sh) bytes）"
    else
        echo "  ❌ 下载失败，WiFi 将无法正常工作！"
        exit 1
    fi

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
    echo ">>> [4] WH3000 Pro WiFi 预置配置完成"

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
exit 0
EOF
    chmod +x files/etc/uci-defaults/30-docker
    echo ">>> [6] Docker 数据目录配置完成（/mnt/mmcblk0p7）"

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
    echo ">>> [4] RE-SP-01B WiFi 预置配置完成"

    cat > files/etc/rc.local << 'EOF'
#!/bin/sh
sleep 8 && wifi up >/dev/null 2>&1
exit 0
EOF
    chmod +x files/etc/rc.local
    echo ">>> [5] WiFi 首启延迟启动完成"

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

echo "========================================"
echo " DIY Part 2 全部完成 · DONGZAI 固件工厂"
echo "========================================"
