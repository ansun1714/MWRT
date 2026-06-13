local sys = require "luci.sys"

local lan_ip = sys.exec("uci -q get network.lan.ipaddr"):gsub("%s+", "")
if lan_ip == "" then lan_ip = "192.168.1.1" end

m = Map("unicast_proxy", translate("单播IPTV代理"),
	translate("将运营商限定网络下的单播直播源（HTTP格式，非组播）" ..
		"通过本机网络转发，使其他网络下的设备也能播放。" ..
		"原理：本机用 socat 把指定端口收到的连接转发到源地址，" ..
		"由于转发由本机发起，使用本机 WAN 的网络环境，" ..
		"因此可以绕开运营商对来源网络的限制。"))

-- ── 全局设置 ──────────────────────────────────────────
g = m:section(NamedSection, "settings", "global", translate("全局设置"))

ddns = g:option(Value, "ddns_host", translate("DDNS 域名"))
ddns.placeholder = "myhome.ddns.net"
ddns.rmempty = true
ddns.description = translate(
	"填写用于远程访问的 DDNS 域名（不含端口和 http://）。" ..
	"DDNS 解析需在「系统 -> 动态DNS」中单独配置好，" ..
	"这里只是用来生成外网播放列表地址。")

-- ── 代理规则 ──────────────────────────────────────────
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

wan = s:option(Flag, "wan_access", translate("公网访问"))
wan.rmempty = false
wan.default = "0"
wan.description = translate(
	"开启后自动在防火墙 WAN 区域放行该端口，" ..
	"配合上方 DDNS 域名即可在外网访问。" ..
	"需要运营商分配公网IP（非NAT），否则无法生效。")

-- ── 访问地址一览 ──────────────────────────────────────
info = m:section(SimpleSection, translate("访问地址一览"))

local ddns_host = m.uci:get("unicast_proxy", "settings", "ddns_host") or ""
local lines = {}

m.uci:foreach("unicast_proxy", "rule", function(sec)
	if sec.enable ~= "1" then return end
	local rname = sec.name or sec[".name"]
	local lport  = sec.listen_port or "?"

	lines[#lines+1] = "<b>" .. pcdata(rname) .. "</b>"
	lines[#lines+1] = translate("局域网") .. ": http://" ..
		lan_ip .. ":" .. lport .. "/原始路径"

	if sec.wan_access == "1" then
		if ddns_host ~= "" then
			lines[#lines+1] = translate("外网") .. ": http://" ..
				pcdata(ddns_host) .. ":" .. lport .. "/原始路径"
		else
			lines[#lines+1] = "<span style='color:orange'>" ..
				translate("外网：已开启公网访问，但未填写 DDNS 域名") ..
				"</span>"
		end
	end

	lines[#lines+1] = "<br/>"
end)

if #lines == 0 then
	lines[1] = translate("暂无已启用的规则")
end

info.description = table.concat(lines, "<br/>")

return m
