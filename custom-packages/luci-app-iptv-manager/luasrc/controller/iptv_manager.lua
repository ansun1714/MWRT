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
end
