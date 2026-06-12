module("luci.controller.unicast_proxy", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/unicast_proxy") then
		return
	end

	entry({"admin", "services", "unicast_proxy"},
		alias("admin", "services", "unicast_proxy", "rules"),
		_("单播IPTV代理"), 65)

	entry({"admin", "services", "unicast_proxy", "rules"},
		cbi("unicast_proxy"), _("代理规则"), 1)

	entry({"admin", "services", "unicast_proxy", "m3u"},
		template("unicast_proxy/m3u_converter"), _("M3U地址转换"), 2)
end
