local m, m_msd, m_rtp, m_proxy, s, o

-- ══ Map 1：全局控制 (/etc/config/iptv_manager) ════════════════
m = Map("iptv_manager",
    translate("IPTV 管理器"),
    translate("统一管理 msd_lite 与 rtp2HTTPd，两套配置独立保存，随时可切换。"))

m:section(SimpleSection).template = "iptv_manager/status"

s = m:section(NamedSection, "global", "global", translate("基本设置"))
s.addremove = false
s.anonymous = true

o = s:option(Flag, "enabled", translate("启用 IPTV 服务"))
o.rmempty = false
o.default = "0"

o = s:option(ListValue, "program", translate("选择程序"),
    translate("选择后保存应用，下方自动切换对应配置区。"))
o:value("msd",       translate("msd_lite  —  轻量 UDP 组播转 HTTP"))
o:value("rtp2httpd", translate("rtp2HTTPd  —  功能完整的 IPTV HTTP 代理"))
o.rmempty = false
o.default = "rtp2httpd"

m:section(SimpleSection).template = "iptv_manager/toggle_js"


-- ══ Map 2：msd_lite 配置 (/etc/config/msd_lite) ══════════════
m_msd = Map("msd_lite",
    translate("msd_lite 配置"),
    translate("以下参数写入 /etc/config/msd_lite，选择「msd_lite」时生效。"))

s = m_msd:section(NamedSection, "config", "msd_lite", "")
s.addremove = false

o = s:option(Value, "source",
    translate("组播来源接口"),
    translate("接收 IPTV 组播包的网络接口，例如 eth0.4"))
o.placeholder = "eth0"
o.rmempty     = false

o = s:option(Value, "port",
    translate("HTTP 输出端口"),
    translate("客户端通过 http://路由器IP:<端口>/组播IP:port 拉流"))
o.placeholder = "4022"
o.datatype    = "port"
o.rmempty     = false

o = s:option(ListValue, "type",
    translate("流类型"),
    translate("UDP：直接转发组播包；RTP：去除 RTP 头后转发"))
o:value("0", "UDP")
o:value("1", "RTP")
o.default  = "0"
o.rmempty  = true

o = s:option(Value, "threads",
    translate("工作线程数"),
    translate("0 = 自动（使用 CPU 核心数）"))
o.placeholder = "0"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "buffer",
    translate("缓冲区大小（字节）"),
    translate("UDP 接收缓冲区，默认 16384"))
o.placeholder = "16384"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "rejointime",
    translate("组播重加入间隔（秒）"),
    translate("定期重新加入组播组，0 = 禁用"))
o.placeholder = "0"
o.datatype    = "uinteger"
o.rmempty     = true


-- ══ Map 3：rtp2HTTPd 配置 (/etc/config/rtp2httpd) ════════════
m_rtp = Map("rtp2httpd",
    translate("rtp2HTTPd 配置"),
    translate("以下参数由 rtp2HTTPd 自身读取（/etc/config/rtp2httpd），选择「rtp2HTTPd」时生效。"))

s = m_rtp:section(TypedSection, "rtp2httpd", "")
s.anonymous = true
s.addremove = false

o = s:option(Value, "port",
    translate("HTTP 监听端口"),
    translate("客户端访问端口，默认 5140"))
o.placeholder = "5140"
o.datatype    = "port"
o.rmempty     = true

o = s:option(ListValue, "advanced_interface_settings",
    translate("接口配置模式"),
    translate("简单：所有流量走同一接口；高级：组播/FCC/RTSP/HTTP 分别指定"))
o:value("0", translate("简单模式 — 统一上游接口"))
o:value("1", translate("高级模式 — 分接口配置"))
o.default  = "0"
o.rmempty  = true

o = s:option(Value, "upstream_interface",
    translate("上游接口（简单模式）"),
    translate("所有流量来源接口，例如 iptv 或 eth0.4"))
o.placeholder = "iptv"
o.rmempty     = true
o:depends("advanced_interface_settings", "0")

o = s:option(Value, "upstream_interface_multicast",
    translate("组播接口"))
o.placeholder = "eth0"
o.rmempty     = true
o:depends("advanced_interface_settings", "1")

o = s:option(Value, "upstream_interface_fcc",
    translate("FCC 快速换台接口"))
o.placeholder = "eth1"
o.rmempty     = true
o:depends("advanced_interface_settings", "1")

o = s:option(Value, "upstream_interface_rtsp",
    translate("RTSP 接口"))
o.placeholder = "eth2"
o.rmempty     = true
o:depends("advanced_interface_settings", "1")

o = s:option(Value, "upstream_interface_http",
    translate("HTTP 上游接口"))
o.placeholder = "eth3"
o.rmempty     = true
o:depends("advanced_interface_settings", "1")

o = s:option(Value, "maxclients",
    translate("最大客户端数"),
    translate("默认 5"))
o.placeholder = "5"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "workers",
    translate("工作线程数"),
    translate("默认 1"))
o.placeholder = "1"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "buffer_pool_max_size",
    translate("缓冲池大小（字节）"),
    translate("默认 16384"))
o.placeholder = "16384"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "udp_rcvbuf_size",
    translate("UDP 接收缓冲区（字节）"),
    translate("默认 524288（512 KB）"))
o.placeholder = "524288"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Flag, "zerocopy_on_send",
    translate("Zero-Copy 发送优化"))
o.rmempty = true
o.default = "0"

o = s:option(Value, "status_page_path",
    translate("状态页面路径"))
o.placeholder = "/status"
o.rmempty     = true

o = s:option(Value, "player_page_path",
    translate("Web 播放器路径"))
o.placeholder = "/player"
o.rmempty     = true

o = s:option(Value, "external_m3u",
    translate("外部 M3U 播放列表 URL"))
o.placeholder = "https://example.com/playlist.m3u"
o.rmempty     = true

o = s:option(Value, "external_m3u_update_interval",
    translate("M3U 更新间隔（秒）"),
    translate("默认 7200"))
o.placeholder = "7200"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "hostname",
    translate("服务器主机名（可选）"))
o.placeholder = "somehost.example.com"
o.rmempty     = true

o = s:option(Flag, "xff",
    translate("转发 X-Forwarded-For"))
o.rmempty = true
o.default = "0"

o = s:option(Value, "cors_allow_origin",
    translate("CORS 允许来源"),
    translate("* 表示所有；留空禁用"))
o.placeholder = "*"
o.rmempty     = true

o = s:option(Value, "r2h_token",
    translate("访问令牌（可选）"))
o.placeholder = "your-secret-token-here"
o.password    = true
o.rmempty     = true

o = s:option(Value, "mcast_rejoin_interval",
    translate("组播重加入间隔（秒）"),
    translate("0 表示禁用"))
o.placeholder = "0"
o.datatype    = "uinteger"
o.rmempty     = true

o = s:option(Value, "fcc_listen_port_range",
    translate("FCC 监听端口范围"),
    translate("例如 40000-40100"))
o.placeholder = "40000-40100"
o.rmempty     = true

o = s:option(Value, "http_proxy_user_agent",
    translate("HTTP 代理 User-Agent"))
o.placeholder = "rtp2httpd-http-proxy/1.0"
o.rmempty     = true

o = s:option(Value, "rtsp_user_agent",
    translate("RTSP User-Agent"))
o.placeholder = "rtp2httpd/custom"
o.rmempty     = true

o = s:option(Value, "rtsp_stun_server",
    translate("RTSP STUN 服务器"))
o.placeholder = "stun.miwifi.com"
o.rmempty     = true

o = s:option(Value, "ffmpeg_path",
    translate("FFmpeg 路径"))
o.placeholder = "ffmpeg"
o.rmempty     = true

o = s:option(Value, "ffmpeg_args",
    translate("FFmpeg 额外参数"))
o.placeholder = "-hwaccel none"
o.rmempty     = true

o = s:option(Flag, "video_snapshot",
    translate("启用视频截图功能"),
    translate("需要 FFmpeg 支持"))
o.rmempty = true
o.default = "0"


-- ══ Map 4：单播IPTV代理 (/etc/config/iptv_manager) ════════════
m_proxy = Map("iptv_manager",
    translate("单播IPTV代理"),
    translate("将运营商限定网络下的单播直播源（HTTP格式，非组播）" ..
        "通过本机转发，使其他网络下的设备也能播放。" ..
        "配合 DDNS 域名可在外网访问。"))

-- 全局设置
s = m_proxy:section(NamedSection, "unicast_settings", "unicast_proxy",
    translate("全局设置"))
s.addremove = false
s.anonymous = true

o = s:option(Value, "ddns_host", translate("DDNS 域名"))
o.placeholder  = "myhome.ddns.net"
o.rmempty      = true
o.description  = translate(
    "填写用于远程访问的 DDNS 域名（不含端口和 http://）。" ..
    "DDNS 解析需在「系统 -> 动态DNS」中单独配置好，" ..
    "这里只是用来生成外网播放列表地址。")

-- 代理规则
s = m_proxy:section(TypedSection, "unicast_rule", translate("代理规则"))
s.template = "cbi/tblsection"
s.anonymous = true
s.addremove = true
s.sortable  = true

o = s:option(Flag, "enable", translate("启用"))
o.rmempty = false
o.default = "1"

o = s:option(Value, "name", translate("备注名称"))
o.placeholder = "江苏联通单播"

o = s:option(Value, "upstream_host", translate("源地址IP"))
o.placeholder = "112.86.202.37"
o.datatype    = "ipaddr"
o.rmempty     = false

o = s:option(Value, "upstream_port", translate("源端口"))
o.placeholder = "8112"
o.datatype    = "port"
o.rmempty     = false

o = s:option(Value, "listen_port", translate("本机监听端口"))
o.placeholder = "8112"
o.datatype    = "port"
o.rmempty     = false

o = s:option(Flag, "wan_access", translate("公网访问"))
o.rmempty    = false
o.default    = "0"
o.description = translate(
    "开启后自动在防火墙 WAN 区域放行该端口，" ..
    "配合上方 DDNS 域名即可在外网访问。" ..
    "需要运营商分配公网IP（非NAT），否则无法生效。")

-- ── 访问地址一览 ─────────────────────────────────────────────
local info = m_proxy:section(SimpleSection, translate("访问地址一览"))

-- pcdata 在 CBI 模型上下文中不可用，定义本地 HTML 转义函数
local function esc(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

local sys = require "luci.sys"
local lan_ip = sys.exec("uci -q get network.lan.ipaddr"):gsub("%s+", "")
if lan_ip == "" then lan_ip = "192.168.1.1" end

local ddns_host = m_proxy.uci:get(
    "iptv_manager", "unicast_settings", "ddns_host") or ""
local lines = {}

m_proxy.uci:foreach("iptv_manager", "unicast_rule", function(sec)
    if sec.enable ~= "1" then return end
    local rname = sec.name or sec[".name"]
    local lport = sec.listen_port or "?"

    lines[#lines+1] = "<b>" .. esc(rname) .. "</b>"
    lines[#lines+1] = translate("局域网") .. ": http://" ..
        esc(lan_ip) .. ":" .. lport .. "/原始路径"

    if sec.wan_access == "1" then
        if ddns_host ~= "" then
            lines[#lines+1] = translate("外网") .. ": http://" ..
                esc(ddns_host) .. ":" .. lport .. "/原始路径"
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

-- ── M3U 转换工具入口（醒目按钮）────────────────────────────
local m3u_entry = m_proxy:section(SimpleSection)
m3u_entry.description =
    '<div style="margin:16px 0 8px 0;padding:14px 16px;' ..
    'background:#f0f8ff;border:1px solid #b0d4f0;border-radius:6px">' ..
    '<span style="font-size:15px;font-weight:bold">📋 ' ..
    translate("M3U 地址转换工具") .. '</span><br/>' ..
    '<span style="color:#555;font-size:13px">' ..
    translate("将运营商原始 M3U 批量替换为本机代理地址，生成可外网访问的播放列表。") ..
    '</span><br/><br/>' ..
    '<a class="cbi-button cbi-button-action" ' ..
    'href="/cgi-bin/luci/admin/services/iptv_manager/m3u" ' ..
    'style="text-decoration:none;padding:6px 18px;font-size:14px">' ..
    '▶ ' .. translate("打开 M3U 地址转换工具") ..
    '</a></div>'

return m, m_msd, m_rtp, m_proxy
