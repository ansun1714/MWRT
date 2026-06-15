module("luci.controller.iptv_manager", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/iptv_manager") then
        return
    end

    local page = entry(
        {"admin", "services", "iptv_manager"},
        cbi("iptv_manager"),
        _("IPTV 管理"),
        60
    )
    page.dependent = true

    local m3u = entry(
        {"admin", "services", "iptv_manager", "m3u"},
        template("iptv_manager/m3u_converter"),
        nil, 61
    )
    m3u.dependent = true
    m3u.leaf = true

    -- 保存 M3U 到路由器供 rtp2httpd 使用
    local save = entry(
        {"admin", "services", "iptv_manager", "save_rtp2httpd_m3u"},
        call("action_save_rtp2httpd_m3u"), nil
    )
    save.leaf = true
end

function action_save_rtp2httpd_m3u()
    local http = luci.http
    local content = http.formvalue("content")

    http.prepare_content("application/json")

    if not content or #content == 0 then
        http.write('{"ok":false,"msg":"content empty"}')
        return
    end

    -- 保存到 web root，让 rtp2httpd 通过 HTTP 加载
    local path = "/www/iptv_unicast.m3u"
    local f = io.open(path, "w")
    if not f then
        http.write('{"ok":false,"msg":"cannot write ' .. path .. '"}')
        return
    end
    f:write(content)
    f:close()

    -- 配置 rtp2httpd external_m3u
    local m3u_url = "http://127.0.0.1/iptv_unicast.m3u"
    os.execute("uci set 'rtp2httpd.@rtp2httpd[0].external_m3u=" .. m3u_url .. "' 2>/dev/null")
    os.execute("uci commit rtp2httpd 2>/dev/null")

    -- 通过 iptv_manager 重载（会重启 rtp2httpd）
    os.execute("/etc/init.d/iptv_manager reload 2>/dev/null &")

    http.write('{"ok":true,"path":"' .. path .. '","m3u_url":"' .. m3u_url .. '"}')
end
