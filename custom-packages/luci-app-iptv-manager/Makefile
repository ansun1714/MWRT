include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-iptv-manager
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-iptv-manager
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI - IPTV 管理器 (msd_lite / rtp2HTTPd)
  DEPENDS:=+luci-base
  PKGARCH:=all
endef

define Package/luci-app-iptv-manager/description
  IPTV 代理服务管理界面，支持在 msd_lite 和 rtp2HTTPd 之间切换，
  每个程序独立配置参数，统一由 init 脚本控制启停。
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-iptv-manager/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/iptv_manager.lua \
	    $(1)/usr/lib/lua/luci/controller/iptv_manager.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/iptv_manager.lua \
	    $(1)/usr/lib/lua/luci/model/cbi/iptv_manager.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/iptv_manager
	$(INSTALL_DATA) ./luasrc/view/iptv_manager/toggle_js.htm \
	    $(1)/usr/lib/lua/luci/view/iptv_manager/toggle_js.htm
	$(INSTALL_DATA) ./luasrc/view/iptv_manager/status.htm \
	    $(1)/usr/lib/lua/luci/view/iptv_manager/status.htm

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/iptv_manager \
	    $(1)/etc/config/iptv_manager

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/iptv_manager \
	    $(1)/etc/init.d/iptv_manager

	$(INSTALL_DIR) $(1)/etc/rtp2httpd
endef

define Package/luci-app-iptv-manager/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -rf /tmp/luci-indexcache
exit 0
endef

define Package/luci-app-iptv-manager/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -rf /tmp/luci-indexcache
exit 0
endef

$(eval $(call BuildPackage,luci-app-iptv-manager))
