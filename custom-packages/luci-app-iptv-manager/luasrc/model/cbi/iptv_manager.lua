local m, m_msd, m_rtp, s, o

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
-- section 名 = "config"，类型 = "msd_lite"，启用选项 = "enable"
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

return m, m_msd, m_rtp
