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

    entry(
        {"admin", "services", "iptv_manager", "m3u"},
        template("iptv_manager/m3u_converter"),
        _("M3U地址转换"),
        61
    ).dependent = true
end
