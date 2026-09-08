#!/bin/bash

DEVICE="${DEVICE:-wh3000pro}"

echo "========================================"
echo " DONGZAI 固件工厂 - DIY Part 2"
echo " 当前设备：$DEVICE"
echo "========================================"

mkdir -p files/etc/uci-defaults
mkdir -p files/etc/config
mkdir -p files/etc/init.d


# ============================================================
# ★ Fix-WIFI
# Linux 6.18 / netifd / mac80211 WiFi Scripts
# ============================================================

case "$DEVICE" in

  wh3000|wh3000pro)

    echo ""
    echo "============================================================"
    echo " Fix-WIFI：检查 MT7981 WiFi Scripts"
    echo "============================================================"

    # --------------------------------------------------------
    # 1. 强制启用 wifi-scripts
    # --------------------------------------------------------

    if grep -q '^CONFIG_PACKAGE_wifi-scripts=' .config; then
        sed -i \
          's/^CONFIG_PACKAGE_wifi-scripts=.*/CONFIG_PACKAGE_wifi-scripts=y/' \
          .config
    else
        echo 'CONFIG_PACKAGE_wifi-scripts=y' >> .config
    fi

    echo "  [OK] CONFIG_PACKAGE_wifi-scripts=y"


    # --------------------------------------------------------
    # 2. 确保基础 WiFi 内核模块
    # --------------------------------------------------------

    WIFI_PACKAGES="
kmod-mac80211
kmod-cfg80211
kmod-mt76-core
kmod-mt76-connac
kmod-mt7981-firmware
kmod-mt7915e
mt7981-wo-firmware
wireless-regdb
iwinfo
rpcd-mod-iwinfo
"

    for pkg in $WIFI_PACKAGES; do

        CONFIG_NAME="CONFIG_PACKAGE_${pkg}"

        if grep -q "^${CONFIG_NAME}=" .config; then

            sed -i \
              "s/^${CONFIG_NAME}=.*/${CONFIG_NAME}=y/" \
              .config

        else

            echo "${CONFIG_NAME}=y" >> .config

        fi

    done

    echo "  [OK] MT7981 WiFi 基础组件已启用"


    # --------------------------------------------------------
    # 3. 检查 wifi-scripts 源码
    # --------------------------------------------------------

    WIFI_SCRIPT_MK="package/network/config/wifi-scripts/Makefile"

    if [ -f "$WIFI_SCRIPT_MK" ]; then

        echo "  [OK] wifi-scripts Makefile"

    else

        echo ""
        echo "  ❌ ERROR：找不到 wifi-scripts"
        echo ""
        echo "  缺少："
        echo "  $WIFI_SCRIPT_MK"
        echo ""
        echo "  为避免生成 WiFi 损坏的固件，停止编译。"
        echo ""

        exit 1

    fi


    # --------------------------------------------------------
    # 4. 检查核心 WiFi 脚本
    # --------------------------------------------------------

    WIFI_SCRIPT_DIR="package/network/config/wifi-scripts/files"

    REQUIRED_WIFI_FILES="
$WIFI_SCRIPT_DIR/lib/netifd/netifd-wireless.sh
"

    for file in $REQUIRED_WIFI_FILES; do

        if [ -f "$file" ]; then

            echo "  [OK] $file"

        else

            echo ""
            echo "  ❌ ERROR：缺少 WiFi 核心文件"
            echo ""
            echo "  $file"
            echo ""
            echo "  停止编译。"
            echo ""

            exit 1

        fi

    done


    echo ""
    echo ">>> WiFi 配置："

    grep -E \
      '^CONFIG_PACKAGE_(wifi-scripts|kmod-mac80211|kmod-cfg80211|kmod-mt76-core|kmod-mt76-connac|kmod-mt7981-firmware|kmod-mt7915e|mt7981-wo-firmware|wireless-regdb|iwinfo|rpcd-mod-iwinfo)=' \
      .config || true

    echo ""
    echo "============================================================"
    echo " ✓ Fix-WIFI 检查通过"
    echo "============================================================"
    echo ""

    ;;

  *)
    echo ">>> 当前设备 $DEVICE 非 MT7981，跳过 Fix-WIFI"
    ;;

esac


# ============================================================
# OpenVPN DCO
# ============================================================

echo ">>> [ovpn-dco] 关闭 OpenVPN DCO..."

for f in feeds/packages/net/openvpn/Config-*.in; do

    [ -f "$f" ] || continue

    sed -i \
      '/ENABLE_DCO/,+8 s/default y.*/default n/' \
      "$f"

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


# ============================================================
# 清理旧配置
# ============================================================

sed -i \
  -e '/^CONFIG_PACKAGE_kmod-ovpn/d' \
  -e '/^CONFIG_OPENVPN_.*ENABLE_DCO=/d' \
  -e '/^CONFIG_PACKAGE_luci-app-webdav=/d' \
  -e '/^CONFIG_PACKAGE_nginx-mod-dav-ext=/d' \
  -e '/^CONFIG_PACKAGE_luci-i18n-webdav/d' \
  .config


# ============================================================
# Crypto
# ============================================================

echo ""
echo ">>> [Crypto] 应用 Linux 6.18 Crypto 配置..."

# 删除可能由旧版本遗留的错误配置
sed -i \
  -e '/^CONFIG_PACKAGE_kmod-crypto-lib-poly1305=/d' \
  -e '/^CONFIG_PACKAGE_kmod-crypto-lib-chacha20=/d' \
  -e '/^CONFIG_PACKAGE_kmod-crypto-lib-chacha20poly1305=/d' \
  .config


cat >> .config << 'EOF'

# ============================================================
# DONGZAI Crypto
# ============================================================

CONFIG_PACKAGE_kmod-crypto-hash=y
CONFIG_PACKAGE_kmod-crypto-aead=y
CONFIG_PACKAGE_kmod-crypto-manager=y
CONFIG_PACKAGE_kmod-crypto-chacha20poly1305=y

# ============================================================
# OpenVPN DCO disabled
# ============================================================

# CONFIG_PACKAGE_kmod-ovpn-dco is not set
# CONFIG_PACKAGE_kmod-ovpn-dco-v2 is not set
# CONFIG_PACKAGE_kmod-ovpn-backports is not set
# CONFIG_OPENVPN_openssl_ENABLE_DCO is not set

# ============================================================
# WebDAV disabled
# ============================================================

# CONFIG_PACKAGE_luci-app-webdav is not set
# CONFIG_PACKAGE_nginx-mod-dav-ext is not set

EOF


echo ">>> [Crypto] 完成"


# ============================================================
# Hostname
# ============================================================

case "$DEVICE" in

  wh3000)
    HOSTNAME="WH3000"
    ;;

  wh3000pro)
    HOSTNAME="WH3000-Pro"
    ;;

  re-sp-01b)
    HOSTNAME="RE-SP-01B"
    ;;

  *)
    HOSTNAME="MWRT"
    ;;

esac


# ============================================================
# System Defaults
# ============================================================

cat > files/etc/uci-defaults/01-system << EOF
#!/bin/sh

uci set system.@system[0].hostname='${HOSTNAME}'

uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'

uci commit system

exit 0
EOF

chmod +x files/etc/uci-defaults/01-system


# ============================================================
# Design Theme
# ============================================================

sed -i \
  's/luci-theme-bootstrap/luci-theme-design/g' \
  package/lean/default-settings/files/zzz-default-settings \
  2>/dev/null


# ============================================================
# Lucky
# ============================================================

find . \
  -type f \
  -name "lucky*" \
  -exec chmod +x {} \; \
  2>/dev/null


# ============================================================
# Sysctl
# ============================================================

cat > files/etc/sysctl.conf << 'EOF'
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
EOF


# ============================================================
# MSD Lite
# ============================================================

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


# ============================================================
# MSD Lite / RTP2HTTPd unified service
# ============================================================

cat > files/etc/init.d/msd_lite << 'INITEOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1

start_service() {

    local enable
    local type
    local port
    local source
    local threads
    local buffer
    local rejointime
    local PROG

    config_load "msd_lite"

    config_get_bool enable "config" "enable" "0"

    [ "$enable" -eq "1" ] || return 0

    config_get type \
        "config" \
        "type" \
        "0"

    config_get port \
        "config" \
        "port" \
        "7088"

    config_get source \
        "config" \
        "source" \
        "eth0"

    config_get threads \
        "config" \
        "threads" \
        "0"

    config_get buffer \
        "config" \
        "buffer" \
        "16384"

    config_get rejointime \
        "config" \
        "rejointime" \
        "0"


    mkdir -p /var/etc


    # ========================================================
    # MSD Lite
    # ========================================================

    if [ "$type" = "0" ]; then

        PROG="/usr/bin/msd_lite"

        cat > /var/etc/msd_lite.conf << XMLEOF

<?xml version="1.0" encoding="utf-8"?>

<msd>

  <log>
    <file>/var/log/msd_lite.log</file>
  </log>

  <threadPool>
    <threadsCountMax>${threads}</threadsCountMax>
    <fBindToCPU>yes</fBindToCPU>
  </threadPool>

  <HTTP>

    <bindList>

      <bind>
        <address>0.0.0.0:${port}</address>
      </bind>

      <bind>
        <address>[::]:${port}</address>
      </bind>

    </bindList>

    <hostnameList>
      <hostname>*</hostname>
    </hostnameList>

  </HTTP>


  <hubProfileList>

    <hubProfile>

      <fDropSlowClients>no</fDropSlowClients>

      <fSocketTCPNoDelay>yes</fSocketTCPNoDelay>

      <precache>${buffer}</precache>

      <ringBufSize>1024</ringBufSize>

      <headersList>

        <header>
          Pragma: no-cache
        </header>

        <header>
          Content-Type: video/mpeg
        </header>

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


    # ========================================================
    # RTP2HTTPd
    # ========================================================

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


    # ========================================================
    # procd
    # ========================================================

    procd_open_instance

    procd_set_param command \
        "$PROG" \
        -c \
        /var/etc/msd_lite.conf

    procd_set_param respawn

    procd_set_param stderr 1

    procd_close_instance

}


reload_service() {

    stop

    start

}


service_triggers() {

    procd_add_reload_trigger \
        "msd_lite"

}

INITEOF

chmod +x files/etc/init.d/msd_lite


# ============================================================
# Device specific configuration
# ============================================================

case "$DEVICE" in


# ============================================================
# WH3000 / WH3000 Pro
# ============================================================

wh3000|wh3000pro)

    echo ""
    echo ">>> 应用 WH3000 / WH3000 Pro 专属配置..."


    # ========================================================
    # WiFi default configuration
    # ========================================================

    cat > files/etc/uci-defaults/99-wifi-ssid << 'EOF'
#!/bin/sh

# ============================================================
# 等待 WiFi PHY
# ============================================================

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
do

    [ -d /sys/class/ieee80211/phy0 ] && break

    sleep 1

done


# ============================================================
# 如果 wireless 不存在，则由 wifi-scripts 生成
# ============================================================

if [ ! -s /etc/config/wireless ]; then

    wifi config

fi


# ============================================================
# 2.4GHz
# ============================================================

if uci -q get wireless.radio0 >/dev/null 2>&1; then

    uci -q set wireless.radio0.disabled='0'

    uci -q set wireless.radio0.country='CN'

    uci -q set wireless.default_radio0.ssid='Camera_mao'

    uci -q set wireless.default_radio0.encryption='psk2'

    uci -q set wireless.default_radio0.key='18921500010'

fi


# ============================================================
# 5GHz
# ============================================================

if uci -q get wireless.radio1 >/dev/null 2>&1; then

    uci -q set wireless.radio1.disabled='0'

    uci -q set wireless.radio1.country='CN'

    uci -q set wireless.default_radio1.ssid='栋仔_5G'

    uci -q set wireless.default_radio1.encryption='psk2'

    uci -q set wireless.default_radio1.key='18851575507'

fi


uci commit wireless


# ============================================================
# 启动 WiFi
# ============================================================

wifi up

exit 0

EOF

    chmod +x files/etc/uci-defaults/99-wifi-ssid


    # ========================================================
    # eMMC fstab
    # ========================================================

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


    # ========================================================
    # Docker eMMC
    # ========================================================

    cat > files/etc/uci-defaults/30-docker << 'EOF'
#!/bin/sh

mkdir -p /mnt/mmcblk0p7/docker

uci set dockerd.globals.data_root='/mnt/mmcblk0p7/docker'

uci commit dockerd

/etc/init.d/dockerd enable

exit 0

EOF

    chmod +x files/etc/uci-defaults/30-docker


    # ========================================================
    # Banner
    # ========================================================

    cat > files/etc/banner << 'EOF'
DONGZAI 固件工厂 · Huasifei WH3000 Pro
Platform: MediaTek MT7981 · ARM
EOF

    ;;


# ============================================================
# RE-SP-01B
# ============================================================

re-sp-01b)

    echo ""
    echo ">>> 应用 RE-SP-01B 专属配置..."


    cat > files/etc/uci-defaults/99-wifi-ssid << 'EOF'
#!/bin/sh

for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
do

    [ -d /sys/class/ieee80211/phy0 ] && break

    sleep 1

done


if [ ! -s /etc/config/wireless ]; then

    wifi config

fi


if uci -q get wireless.radio0 >/dev/null 2>&1; then

    uci -q set wireless.radio0.disabled='0'

    uci -q set wireless.default_radio0.ssid='RE-SP-01B'

fi


if uci -q get wireless.radio1 >/dev/null 2>&1; then

    uci -q set wireless.radio1.disabled='0'

    uci -q set wireless.default_radio1.ssid='RE-SP-01B_5G'

fi


uci commit wireless

wifi up

exit 0

EOF

    chmod +x files/etc/uci-defaults/99-wifi-ssid


    cat > files/etc/banner << 'EOF'
DONGZAI 固件工厂 · JDCloud RE-SP-01B
Platform: MediaTek MT7621 · MIPS
EOF

    ;;


esac


# ============================================================
# 最终检查
# ============================================================

echo ""
echo "============================================================"
echo " DONGZAI DIY Part 2 最终配置检查"
echo "============================================================"


if [ "$DEVICE" = "wh3000" ] || [ "$DEVICE" = "wh3000pro" ]; then

    echo ""
    echo ">>> MT7981 WiFi："

    grep -E \
      '^CONFIG_PACKAGE_(wifi-scripts|kmod-mac80211|kmod-cfg80211|kmod-mt76-core|kmod-mt76-connac|kmod-mt7981-firmware|kmod-mt7915e|mt7981-wo-firmware|wireless-regdb|iwinfo|rpcd-mod-iwinfo)=' \
      .config || true


    if ! grep -q '^CONFIG_PACKAGE_wifi-scripts=y$' .config; then

        echo ""
        echo "❌ ERROR：wifi-scripts 未进入最终配置"
        exit 1

    fi

    echo ""
    echo "✓ wifi-scripts 已进入最终 .config"

fi


echo ""
echo ">>> OpenVPN DCO："

grep -E \
  'CONFIG_PACKAGE_kmod-ovpn|CONFIG_OPENVPN_openssl_ENABLE_DCO' \
  .config || true


echo ""
echo ">>> Crypto："

grep -E \
  '^CONFIG_PACKAGE_kmod-crypto-' \
  .config || true


echo ""
echo "============================================================"
echo " DIY Part 2 全部完成"
echo " 当前设备：$DEVICE"
echo "============================================================"
