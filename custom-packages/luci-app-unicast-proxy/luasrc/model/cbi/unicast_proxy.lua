local sys = require "luci.sys"

local lan_ip = sys.exec("uci -q get network.lan.ipaddr"):gsub("%s+", "")
if lan_ip == "" then lan_ip = "192.168.1.1" end

m = Map("unicast_proxy", translate("单播IPTV代理"),
	translate("将运营商限定网络下的单播直播源（HTTP格式，非组播）" ..
		"通过本机网络转发，使其他网络下的设备也能播放。" ..
		"原理：本机用 socat 把指定端口收到的连接转发到源地址，" ..
		"由于转发由本机发起，使用本机 WAN 的网络环境，" ..
		"因此可以绕开运营商对来源网络的限制。"))

s = m:section(TypedSection, "rule", translate("代理规则"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true
s.sortable  = true

enable = s:option(Flag, "enable", translate("启用"))
enable.rmempty = false
enable.default = "1"

name = s:option(Value, "name", translate("备注名称"))
name.placeholder = "江苏联通单播"

uh = s:option(Value, "upstream_host", translate("源地址IP"))
uh.placeholder = "112.86.202.37"
uh.datatype = "ipaddr"
uh.rmempty = false

up = s:option(Value, "upstream_port", translate("源端口"))
up.placeholder = "8112"
up.datatype = "port"
up.rmempty = false

lp = s:option(Value, "listen_port", translate("本机监听端口"))
lp.placeholder = "8112"
lp.datatype = "port"
lp.rmempty = false

info = m:section(SimpleSection, translate("使用说明"))
info.description = translate("规则保存并应用后，访问地址格式为：") ..
	" http://" .. lan_ip .. ":本机监听端口/原始路径 " ..
	translate("例如") .. ": http://" .. lan_ip ..
	":8112/JSBC_iptv/C10000037@JSBC"

return m
