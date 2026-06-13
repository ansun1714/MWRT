include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-unicast-proxy
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=DONGZAI

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-unicast-proxy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for IPTV Unicast Proxy (DONGZAI)
  DEPENDS:=+socat +lua +luci-base
  PKGARCH:=all
endef

define Package/luci-app-unicast-proxy/description
  DONGZAI 固件工厂：单播 IPTV 代理，将运营商限定网络下的
  单播直播源通过本机转发，使其他网络下的设备也能播放。
endef

define Build/Compile
endef

define Package/luci-app-unicast-proxy/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/unicast_proxy \
		$(1)/etc/config/unicast_proxy

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/unicast_proxy \
		$(1)/etc/init.d/unicast_proxy

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/unicast_proxy.lua \
		$(1)/usr/lib/lua/luci/controller/unicast_proxy.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/unicast_proxy.lua \
		$(1)/usr/lib/lua/luci/model/cbi/unicast_proxy.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/unicast_proxy
	$(INSTALL_DATA) ./luasrc/view/unicast_proxy/m3u_converter.htm \
		$(1)/usr/lib/lua/luci/view/unicast_proxy/m3u_converter.htm
endef

$(eval $(call BuildPackage,luci-app-unicast-proxy))
