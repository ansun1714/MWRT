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
# ★ Fix-qmodem：关闭无法编译的 sipd/voip 并斩断 Makefile 依赖
# ════════════════════════════════════════════════════════════

echo ">>> [qmodem] 关闭无法编译的 sipd/voip..."

sed -i \
  -e '/^CONFIG_PACKAGE_qmodem-sipd=/d' \
  -e '/^CONFIG_PACKAGE_qmodem-voip=/d' \
  .config

cat >> .config << 'EOF'
# CONFIG_PACKAGE_qmodem-sipd is not set
# CONFIG_PACKAGE_qmodem-voip is not set
EOF

# ★ 去掉 sms 等其他插件对 sipd 的 Makefile 依赖
echo ">>> [qmodem] 去掉 sms 对 sipd 的依赖..."
find feeds/qmodem package/feeds/qmodem -name Makefile 2>/dev/null | while read -r f; do
    sed -i \
      -e 's/+qmodem-sipd//' \
      -e 's/+qmodem-voip//' \
      "$f"
done

echo ">>> [qmodem] 完成"

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
# ★ Fix-songloft：修复 songloft 启动脚本（终极实测完美版）
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
DB_DEFAULT=/etc/songloft/data
MUSIC_DEFAULT=/mnt/sda1/music

LOGGER="logger -t songloft"

start_instance() {
    local cfg="$1"
    local enabled listen_port db_path base_path admin_username admin_password bin_path web_path music_dir
    
    config_get_bool enabled "$cfg" "enabled" "0"
    config_get listen_port "$cfg" "listen_port" "58091"
    config_get db_path "$cfg" "db_path" "$DB_DEFAULT"
    config_get base_path "$cfg" "base_path" ""
    config_get admin_username "$cfg" "admin_username" ""
    config_get admin_password "$cfg" "admin_password" ""
    config_get bin_path "$cfg" "bin_path" "$PROG_DEFAULT"
    config_get web_path "$cfg" "web_path" "$WEB_DEFAULT"
    config_get music_dir "$cfg" "music_dir" "$MUSIC_DEFAULT"

    [ "$enabled" = "1" ] || return 0

    if [ ! -x "$bin_path" ]; then
        ${LOGGER} "未找到可执行文件: $bin_path"
        return 1
    fi
    
    mkdir -p "$db_path"

    # ★★★ 终极软链接兜底（无论程序逻辑怎么变，都指向真实路径） ★★★
    if [ -d "$music_dir" ]; then
        if [ ! -e "$web_path/music" ]; then
            ln -sf "$music_dir" "$web_path/music"
            ${LOGGER} "已创建软链接: $web_path/music -> $music_dir"
        fi
        if [ ! -e "$db_path/music" ]; then
            ln -sf "$music_dir" "$db_path/music"
            ${LOGGER} "已创建软链接: $db_path/music -> $music_dir"
        fi
    fi

    procd_open_instance "songloft.$cfg"
    procd_set_param command "$bin_path"
    procd_set_param env LISTEN_PORT="$listen_port"
    procd_set_param env DB_PATH="$db_path"
    procd_set_param env WEB_ROOT="$web_path"
    procd_set_param env MUSIC_DIR="$music_dir"
    procd_set_param cwd "$web_path"
    
    [ -n "$base_path" ] && procd_append_param env BASE_PATH="$base_path"
    [ -n "$admin_username" ] && procd_append_param env ADMIN_USERNAME="$admin_username"
    [ -n "$admin_password" ] && procd_append_param env ADMIN_PASSWORD="$admin_password"
    
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

start_service() {
    config_load songloft
    config_foreach start_instance songloft
}

stop_service() { :; }
service_triggers() { procd_add_reload_trigger "songloft"; }
reload_service() { stop; start; }
EOF
chmod +x files/etc/init.d/songloft
echo ">>> [3.5] songloft 启动脚本修复完成"

# ════════════════════════════════════════════════════════════
# ★ 直接修改 luci-app-songloft 源码包，注入音乐路径选项
# ════════════════════════════════════════════════════════════
echo ">>> [3.6] 修改 luci-app-songloft 源码包，添加音乐路径选项..."

# 根据 diy-part1.sh 的路径，源码包在 package/luci-app-songloft
LUCI_SONGLOFT_DIR="package/luci-app-songloft"

if [ ! -d "$LUCI_SONGLOFT_DIR" ]; then
    echo "  ❌ 找不到 $LUCI_SONGLOFT_DIR，跳过修改"
else
    # 定位需要覆盖的 config.lua 路径（CBI 模型）
    TARGET_DIR="$LUCI_SONGLOFT_DIR/root/usr/lib/lua/luci/model/cbi/songloft"
    mkdir -p "$TARGET_DIR"

    cat > "$TARGET_DIR/config.lua" << 'EOF'
local m, s, o

m = Map("songloft", translate("SongLoft 音乐服务"),
        translate("SongLoft 是一款轻量级自建音乐服务，支持本地音乐管理、网络歌曲、电台及歌单等功能。"))

local is_running = (luci.sys.call("pidof songloft >/dev/null 2>&1") == 0)

s = m:section(TypedSection, "songloft", translate("基础设置"))
s.anonymous = true

o = s:option(DummyValue, "_status", translate("服务状态"))
o.rawhtml = true
if is_running then
    o.value = '<span style="color: green; font-weight: bold;">SongLoft 运行中</span> <a href="http://192.168.1.1:58091" target="_blank" class="btn cbi-button cbi-button-apply" style="padding: 5px 15px;">打开管理界面</a>'
else
    o.value = '<span style="color: red; font-weight: bold;">SongLoft 未运行</span>'
end

o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false

o = s:option(Value, "listen_port", translate("监听端口"))
o.datatype = "port"
o.default = "58091"

o = s:option(Value, "db_path", translate("数据目录"))
o.default = "/etc/songloft/data"
o.description = translate("SongLoft 的工作目录，用于存放数据库及音乐索引")

-- ★ 新增：音乐库目录选项
o = s:option(Value, "music_dir", translate("音乐库目录（绝对路径）"))
o.default = "/mnt/sda1/music"
o.rmempty = false
o.description = translate("例如 /mnt/sda1/music，确保路径存在且可读")

o = s:option(Value, "base_path", translate("URL 基础路径"))
o.rmempty = true

o = s:option(Value, "admin_username", translate("管理员用户名"))
o.rmempty = true

o = s:option(Value, "admin_password", translate("管理员密码"))
o.password = true
o.rmempty = true

o = s:option(Value, "bin_path", translate("程序路径"))
o.default = "/usr/bin/songloft"
o.rmempty = true

o = s:option(Value, "web_path", translate("Web 界面目录"))
o.default = "/usr/share/songloft/web-embedded"
o.rmempty = true

function m.on_after_commit(self)
    luci.sys.call("/etc/init.d/songloft restart >/dev/null 2>&1")
    luci.sys.exec("sleep 1")
end

return m
EOF
    echo "  ✓ 成功覆盖 luci-app-songloft 源码包中的 config.lua"
fi
echo ">>> [3.6] Songloft 原生 LuCI 增强完成"

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
