#!/bin/bash
DEVICE="${DEVICE:-wh3000pro}"

echo "========================================"
echo " DONGZAI 固件工厂 - DIY Part 2"
echo " 当前设备：$DEVICE"
echo "========================================"

mkdir -p files/etc/uci-defaults files/etc/config files/etc/init.d

# ============================================================
# Fix-socat：修复 feeds/packages/net/socat 的错误 conffile
# 当前 socat Makefile 声明 /etc/config/socat，但部分 feed 版本
# 未携带对应 files/socat.config，导致 package/install 阶段：
#   find: .../socat/etc/config/socat: No such file or directory
# 这里只删除错误的 conffile 声明，不删除 socat 本体。
# ============================================================
echo ">>> [Fix-socat] 修复 socat package/install..."

SOCAT_MAKEFILE="feeds/packages/net/socat/Makefile"

if [ -f "$SOCAT_MAKEFILE" ]; then
    if grep -q '^define Package/socat/conffiles$' "$SOCAT_MAKEFILE"; then
        sed -i '/^define Package\/socat\/conffiles$/,/^endef$/d' "$SOCAT_MAKEFILE"
        echo ">>> [Fix-socat] 已移除错误的 /etc/config/socat conffile 声明"
    else
        echo ">>> [Fix-socat] 未发现 conffile 声明，跳过"
    fi

    # 确保缓存中的旧 socat 构建结果不会继续触发同一错误
    rm -rf build_dir/target-*/socat-* 2>/dev/null || true
    rm -f staging_dir/target-*/stamp/.socat_installed 2>/dev/null || true
else
    echo ">>> [Fix-socat] 未找到 $SOCAT_MAKEFILE，跳过"
fi


# ============================================================
# Fix-WIFI：MT7981 WiFi Scripts
# ============================================================
case "$DEVICE" in
wh3000|wh3000pro)
    echo ">>> [Fix-WIFI] 补齐 wifi-scripts..."
    WIFI_DIR="package/network/config/wifi-scripts"
    rm -rf "$WIFI_DIR"
    mkdir -p "$WIFI_DIR/files/lib/netifd"

    cat > "$WIFI_DIR/Makefile" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=wifi-scripts
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/wifi-scripts
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=WiFi configuration scripts
  DEPENDS:=+netifd +libubox +ubus
  PKGARCH:=all
endef

define Build/Prepare
endef
define Build/Configure
endef
define Build/Compile
endef

define Package/wifi-scripts/install
	$(INSTALL_DIR) $(1)/lib/netifd
	$(INSTALL_BIN) ./files/lib/netifd/netifd-wireless.sh \
		$(1)/lib/netifd/netifd-wireless.sh
endef

$(eval $(call BuildPackage,wifi-scripts))
EOF

    curl -fL --retry 3 \
      https://raw.githubusercontent.com/openwrt/openwrt/v24.10.5/package/network/config/wifi-scripts/files/lib/netifd/netifd-wireless.sh \
      -o "$WIFI_DIR/files/lib/netifd/netifd-wireless.sh"

    chmod 0755 "$WIFI_DIR/files/lib/netifd/netifd-wireless.sh"

    if [ ! -s "$WIFI_DIR/files/lib/netifd/netifd-wireless.sh" ]; then
        echo "❌ ERROR：netifd-wireless.sh 下载失败"
        exit 1
    fi

    echo ">>> [Fix-WIFI] wifi-scripts 已补齐"
    ;;
esac

# ============================================================
# MT7981 WiFi
# ============================================================
case "$DEVICE" in
wh3000|wh3000pro)
    sed -i \
        -e '/^CONFIG_PACKAGE_wifi-scripts=/d' \
        -e '/^CONFIG_PACKAGE_kmod-mac80211=/d' \
        -e '/^CONFIG_PACKAGE_kmod-cfg80211=/d' \
        -e '/^CONFIG_PACKAGE_kmod-mt76-core=/d' \
        -e '/^CONFIG_PACKAGE_kmod-mt76-connac=/d' \
        -e '/^CONFIG_PACKAGE_kmod-mt7915e=/d' \
        -e '/^CONFIG_PACKAGE_kmod-mt7981-firmware=/d' \
        -e '/^CONFIG_PACKAGE_mt7981-wo-firmware=/d' \
        -e '/^CONFIG_PACKAGE_wireless-regdb=/d' \
        -e '/^CONFIG_PACKAGE_iwinfo=/d' \
        -e '/^CONFIG_PACKAGE_rpcd-mod-iwinfo=/d' \
        .config

    cat >> .config << 'EOF'

CONFIG_PACKAGE_wifi-scripts=y
CONFIG_PACKAGE_kmod-mac80211=y
CONFIG_PACKAGE_kmod-cfg80211=y
CONFIG_PACKAGE_kmod-mt76-core=y
CONFIG_PACKAGE_kmod-mt76-connac=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_kmod-mt7981-firmware=y
CONFIG_PACKAGE_mt7981-wo-firmware=y
CONFIG_PACKAGE_wireless-regdb=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_rpcd-mod-iwinfo=y

EOF
    echo ">>> [WiFi] MT7981 WiFi 组件已启用"
    ;;
esac

# ============================================================
# OpenVPN DCO
# ============================================================
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

rm -rf feeds/packages/kernel/ovpn-dco package/feeds/packages/ovpn-dco

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
sed -i \
    -e '/^CONFIG_PACKAGE_kmod-crypto-lib-poly1305=/d' \
    -e '/^CONFIG_PACKAGE_kmod-crypto-lib-chacha20=/d' \
    -e '/^CONFIG_PACKAGE_kmod-crypto-lib-chacha20poly1305=/d' \
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

# CONFIG_PACKAGE_luci-app-webdav is not set
# CONFIG_PACKAGE_nginx-mod-dav-ext is not set
EOF

# ============================================================
# System
# ============================================================
case "$DEVICE" in
    wh3000) HOSTNAME="WH3000" ;;
    wh3000pro) HOSTNAME="WH3000-Pro" ;;
    re-sp-01b) HOSTNAME="RE-SP-01B" ;;
    *) HOSTNAME="MWRT" ;;
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

sed -i 's/luci-theme-bootstrap/luci-theme-design/g' \
    package/lean/default-settings/files/zzz-default-settings 2>/dev/null

find . -type f -name "lucky*" -exec chmod +x {} \; 2>/dev/null

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

cat > files/etc/init.d/msd_lite << 'INITEOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

start_service() {
    local enable type port source threads buffer rejointime PROG
    config_load "msd_lite"
    config_get_bool enable "config" "enable" "0"
    [ "$enable" -eq "1" ] || return 0
    config_get type "config" "type" "0"
    config_get port "config" "port" "7088"
    config_get source "config" "source" "eth0"
    config_get threads "config" "threads" "0"
    config_get buffer "config" "buffer" "16384"
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

# ============================================================
# Device specific
# ============================================================
case "$DEVICE" in
wh3000|wh3000pro)
    echo ">>> 应用 WH3000 / WH3000 Pro 专属配置..."

    cat > files/etc/uci-defaults/99-wifi-ssid << 'EOF'
#!/bin/sh
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    [ -d /sys/class/ieee80211/phy0 ] && break
    sleep 1
done

if [ ! -s /etc/config/wireless ]; then
    wifi config
fi

if uci -q get wireless.radio0 >/dev/null 2>&1; then
    uci -q set wireless.radio0.disabled='0'
    uci -q set wireless.radio0.country='CN'
    uci -q set wireless.default_radio0.ssid='Camera_mao'
    uci -q set wireless.default_radio0.encryption='psk2'
    uci -q set wireless.default_radio0.key='18921500010'
fi

if uci -q get wireless.radio1 >/dev/null 2>&1; then
    uci -q set wireless.radio1.disabled='0'
    uci -q set wireless.radio1.country='CN'
    uci -q set wireless.default_radio1.ssid='栋仔_5G'
    uci -q set wireless.default_radio1.encryption='psk2'
    uci -q set wireless.default_radio1.key='18851575507'
fi

uci commit wireless
wifi up
exit 0
EOF
    chmod +x files/etc/uci-defaults/99-wifi-ssid

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

    cat > files/etc/banner << 'EOF'
DONGZAI 固件工厂 · Huasifei WH3000 Pro
Platform: MediaTek MT7981 · ARM
EOF
    ;;

re-sp-01b)
    echo ">>> 应用 RE-SP-01B 专属配置..."

    cat > files/etc/uci-defaults/99-wifi-ssid << 'EOF'
#!/bin/sh
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
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
# Final check
# ============================================================
echo "========================================"
echo " DONGZAI DIY Part 2 最终检查"
echo "========================================"

if [ "$DEVICE" = "wh3000" ] || [ "$DEVICE" = "wh3000pro" ]; then
    grep -E '^CONFIG_PACKAGE_(wifi-scripts|kmod-mac80211|kmod-cfg80211|kmod-mt76-core|kmod-mt76-connac|kmod-mt7915e|kmod-mt7981-firmware|mt7981-wo-firmware|wireless-regdb|iwinfo|rpcd-mod-iwinfo)=' .config || true
    test -s package/network/config/wifi-scripts/Makefile || exit 1
    test -s package/network/config/wifi-scripts/files/lib/netifd/netifd-wireless.sh || exit 1
    echo ">>> [OK] wifi-scripts 源码存在"
    echo ">>> [OK] netifd-wireless.sh 存在"
fi


echo ">>> [Fix-socat] 最终检查..."
if [ -f feeds/packages/net/socat/Makefile ]; then
    if grep -q '^define Package/socat/conffiles$' feeds/packages/net/socat/Makefile; then
        echo "❌ ERROR：socat conffile 修复未生效"
        exit 1
    fi
    echo ">>> [OK] socat conffile 声明已修复"
fi

echo "========================================"
echo " DIY Part 2 全部完成"
echo " 当前设备：$DEVICE"
echo "========================================"
