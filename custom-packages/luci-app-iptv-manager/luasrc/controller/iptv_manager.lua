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

    -- ════════════════════════════════════════════════════════════
    -- 存为本地文件，用 file:// 协议直接告知 rtp2httpd
    --
    -- 改进说明（参考 rtp2httpd 官方文档 m3u-integration）：
    --   external-m3u 原生支持 file:///path/to/playlist.m3u
    --   不再走 http://127.0.0.1/xxx 自我请求那一套，
    --   省掉 curl/wget/uclient-fetch 依赖，rtp2httpd 直接读文件，
    --   速度更快、更稳定，也不受 /www 是否可写、HTTP 服务是否
    --   正常监听等因素影响。
    --
    -- 存放路径选 /etc/rtp2httpd/ 而非 /www/，避免和网页静态资源
    -- 混在一起，且 /etc 在 overlay 上更适合存配置类数据。
    -- ════════════════════════════════════════════════════════════
    local dir = "/etc/rtp2httpd"
    os.execute("mkdir -p " .. dir)

    local path = dir .. "/iptv_unicast.m3u"
    local f = io.open(path, "w")
    if not f then
        http.write('{"ok":false,"msg":"cannot write ' .. path .. '"}')
        return
    end
    f:write(content)
    f:close()

    local m3u_uri = "file://" .. path

    os.execute("uci set 'rtp2httpd.@rtp2httpd[0].external_m3u=" ..
        m3u_uri .. "' 2>/dev/null")

    -- file:// 本地文件没有网络更新的必要，关闭自动更新轮询
    -- （0 = 禁用自动更新，用户每次重新转换+保存即视为手动更新）
    os.execute(
        "uci set 'rtp2httpd.@rtp2httpd[0].external_m3u_update_interval=0' " ..
        "2>/dev/null"
    )

    os.execute("uci commit rtp2httpd 2>/dev/null")

    -- 重载 iptv_manager（按当前选择的程序重启对应服务）
    os.execute("/etc/init.d/iptv_manager reload 2>/dev/null &")

    http.write('{"ok":true,"path":"' .. path ..
        '","m3u_uri":"' .. m3u_uri .. '"}')
end
