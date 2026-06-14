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

    -- nil 标题 = 不显示在侧边栏，不产生子菜单展开
    -- 通过主页面按钮访问，URL 仍然有效
    local m3u = entry(
        {"admin", "services", "iptv_manager", "m3u"},
        template("iptv_manager/m3u_converter"),
        nil,
        61
    )
    m3u.dependent = true
    m3u.leaf = true
end
