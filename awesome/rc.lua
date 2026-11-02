local gears     = require("gears")
local awful     = require("awful")
require("awful.autofocus")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local naughty   = require("naughty")

if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical, title = "navi: config error", text = awesome.startup_errors })
end
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        if in_error then return end
        in_error = true
        naughty.notify({ preset = naughty.config.presets.critical, title = "navi: error", text = tostring(err) })
        in_error = false
    end)
end

local DPI = 192
beautiful.xresources.set_dpi(DPI)
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/navi/theme.lua")
local dpi  = beautiful.xresources.apply_dpi
local c    = beautiful.c
local conf = gears.filesystem.get_configuration_dir()

local terminal = "env WINIT_X11_SCALE_FACTOR=randr alacritty"
local browser  = os.getenv("BROWSER") or "thorium-browser"
local music    = "spotify-launcher"
local launcher = "rofi -show drun"
local files    = terminal .. " --class yazi -e yazi"
local monitor  = terminal .. " -e btop"
local mixer    = "pavucontrol"
local super    = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

local function color(col, text) return "<span foreground='" .. col .. "'>" .. gears.string.xml_escape(text) .. "</span>" end
local function kv(k, v, vcol) return color(c.accent, k .. ": ") .. color(vcol or c.fg, v) end
local function read(path)
    local f = io.open(path); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end

local function trunc(str, n)
    if (utf8.len(str) or 0) <= n then return str end
    return str:sub(1, utf8.offset(str, n) - 1) .. "…"
end
local function sh(cmd) return function() awful.spawn.with_shell(cmd) end end

local has_cache = {}
local function has(bin)
    if has_cache[bin] then return true end
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        if gears.filesystem.file_executable(dir .. "/" .. bin) then has_cache[bin] = true; return true end
    end
    return false
end

do
    local lookup = require("menubar.utils").lookup_icon
    naughty.config.notify_callback = function(args)
        local i = args.icon
        if type(i) == "string" and i ~= "" and not i:match("^/") and not i:match("^file://") then
            args.icon = lookup(i) or nil
        end
        return args
    end
end

local osd = {}
osd.label = wibox.widget.textbox()
osd.bar   = wibox.widget { widget = wibox.widget.progressbar, max_value = 100, value = 0,
                           color = c.accent, background_color = c.line }
osd.barbox = wibox.widget { osd.bar, widget = wibox.container.constraint, strategy = "exact" }
osd.popup = awful.popup {
    widget = { { osd.label, { osd.barbox, valign = "center", widget = wibox.container.place },
                 layout = wibox.layout.fixed.horizontal, id = "row" },
               widget = wibox.container.margin, id = "pad" },
    ontop = true, visible = false, bg = c.black, border_color = c.accent, input_passthrough = true,
}
osd.timer = gears.timer({ timeout = 1.2, single_shot = true, callback = function() osd.popup.visible = false end })
local function osd_show(name, pct, muted)
    local s = awful.screen.focused()
    osd.popup.screen = s
    osd.popup.border_width = math.max(1, dpi(1, s))
    osd.popup.widget.margins = dpi(10, s)
    osd.popup.widget:get_children_by_id("row")[1].spacing = dpi(10, s)
    osd.barbox.width, osd.barbox.height = dpi(160, s), math.max(2, dpi(3, s))
    osd.bar.color = muted and c.red or c.accent
    osd.bar.value = math.min(100, pct)
    osd.label:set_markup(kv(name, muted and "muted" or string.format("%3d%%", pct), muted and c.red or c.fg))
    osd.popup.visible = true
    awful.placement.bottom(osd.popup, { parent = s, honor_workarea = true, margins = dpi(60, s) })
    osd.timer:again()
end

local function follow(cmd, pattern, on_line)
    awful.spawn.easy_async_with_shell("pkill -f '" .. pattern .. "'; true", function()
        awful.spawn.with_line_callback(cmd, { stdout = on_line })
    end)
end

local powermenu = awful.menu({ items = {
    { "lock screen", os.getenv("HOME") .. "/.local/bin/navi-lock" },
    { "log out",     function() awesome.quit() end },
    { "sleep",       "systemctl suspend" },
    { "restart",     "systemctl reboot" },
    { "shut down",   "systemctl poweroff" },
}})

local function textw()
    local w = wibox.widget.textbox()
    local last
    local set = w.set_markup
    function w:set_markup(m) if m ~= last then last = m; set(self, m) end end
    return w
end

local audio = textw()
local function audio_read()
    awful.spawn.easy_async({ "pactl", "get-sink-volume", "@DEFAULT_SINK@" }, function(vol)
        awful.spawn.easy_async({ "pactl", "get-sink-mute", "@DEFAULT_SINK@" }, function(mute)
            local v = tonumber(vol:match("(%d+)%%")) or 0
            if mute:match("yes") then audio:set_markup(kv("audio", "muted", c.red))
            else audio:set_markup(kv("audio", v .. "%")) end
            if osd.audio then osd.audio = false; osd_show("vol", v, mute:match("yes")) end
        end)
    end)
end

local audio_timer = gears.timer({ timeout = 0.08, single_shot = true, callback = audio_read })
local function audio_update() audio_timer:again() end
local function volume(arg) return function()
    osd.audio = true
    awful.spawn.easy_async("pactl " .. arg, audio_update)
end end

local vol_up   = function()
    osd.audio = true
    awful.spawn.easy_async({ "pactl", "get-sink-volume", "@DEFAULT_SINK@" }, function(out)
        local v = tonumber(out:match("(%d+)%%")) or 0
        awful.spawn.easy_async({ "pactl", "set-sink-mute", "@DEFAULT_SINK@", "0" }, function()
            awful.spawn.easy_async({ "pactl", "set-sink-volume", "@DEFAULT_SINK@", math.min(100, v + 5) .. "%" }, audio_update)
        end)
    end)
end
local vol_down = volume("set-sink-volume @DEFAULT_SINK@ -5%")
local vol_mute = volume("set-sink-mute @DEFAULT_SINK@ toggle")
audio:buttons(gears.table.join(
    awful.button({}, 1, vol_mute),
    awful.button({}, 3, function() awful.spawn(mixer) end),
    awful.button({}, 4, vol_up),
    awful.button({}, 5, vol_down)))
audio_update()
follow({ "pactl", "subscribe" }, "^pactl subscribe$", function(line) if line:match(" on sink #") or line:match(" on server") then audio_update() end end)

local mem = textw()
local cpu = textw()
local bat = textw()
local cpu_last = { 0, 0 }
local rapl_last = nil
local panel_ac  = nil
local bat_warned = 100
local BAT = "/sys/class/power_supply/BAT1"
local bat_limit
local rapl_max  = tonumber(read("/sys/class/powercap/intel-rapl:0/max_energy_range_uj") or "") or 2^40
local function tick_stats()
    local m = read("/proc/meminfo") or ""
    local total = tonumber(m:match("MemTotal:%s+(%d+)")) or 1
    local avail = tonumber(m:match("MemAvailable:%s+(%d+)")) or 0
    mem:set_markup(kv("mem", math.floor((1 - avail / total) * 100) .. "%"))

    local l = (read("/proc/stat") or ""):match("^cpu%s+([^\n]+)") or ""
    local n, sum = {}, 0
    for x in l:gmatch("%d+") do n[#n + 1] = tonumber(x); sum = sum + tonumber(x) end
    local idle = (n[4] or 0) + (n[5] or 0)
    local pct = sum > cpu_last[1] and math.floor((1 - (idle - cpu_last[2]) / (sum - cpu_last[1])) * 100) or 0
    cpu_last = { sum, idle }

    local e = tonumber(read("/sys/class/powercap/intel-rapl:0/energy_uj") or "")
    local watts = ""
    if e then
        local clock = (read("/proc/uptime") or "0"):match("^(%S+)")
        clock = tonumber(clock) or 0
        if rapl_last and clock > rapl_last[2] then
            local de = e - rapl_last[1]
            if de < 0 then de = de + rapl_max end
            watts = string.format(" %.0fw", de / 1e6 / (clock - rapl_last[2]))
        end
        rapl_last = { e, clock }
    end
    cpu:set_markup(kv("cpu", pct .. "%" .. watts, pct > 85 and c.red or c.fg))

    local ue  = read(BAT .. "/uevent") or ""
    local cap = tonumber(ue:match("POWER_SUPPLY_CAPACITY=(%d+)"))
    local st  = ue:match("POWER_SUPPLY_STATUS=(%a+)") or ""
    if cap then
        if bat_limit == nil then bat_limit = tonumber(read(BAT .. "/charge_control_end_threshold") or "") or false end
        local limit = bat_limit or nil
        local uv = tonumber(ue:match("POWER_SUPPLY_VOLTAGE_NOW=(%d+)")) or 0
        local ua = tonumber(ue:match("POWER_SUPPLY_CURRENT_NOW=(%d+)")) or 0
        local bw = uv * ua / 1e12
        local flow = ""
        if st == "Discharging" and bw > 0.5 then flow = string.format(" -%.0fw", bw)
        elseif st == "Charging" and bw > 0.5 then flow = string.format(" +%.0fw", bw) end
        local txt = cap .. "%" .. flow .. ((limit and limit < 100) and (" /" .. limit) or "")
        bat:set_markup(kv("bat", txt, (cap <= 15 and st == "Discharging") and c.red or c.fg))
        if st ~= "Discharging" then bat_warned = 100
        else
            for _, lvl in ipairs({ 5, 10, 20 }) do
                if cap <= lvl and bat_warned > lvl then
                    bat_warned = lvl
                    naughty.notify({ title = "battery " .. cap .. "%", text = lvl <= 5 and "plug in now" or "find a charger",
                                     timeout = lvl <= 10 and 0 or 8, fg = c.red, border_color = c.red })
                    break
                end
            end
        end
    end

    local ac = (read("/sys/class/power_supply/ACAD/online") or ""):match("1") and true or false
    if ac ~= panel_ac then
        local first = panel_ac == nil
        panel_ac = ac
        local rate = ac and "240" or "60"
        require("visualizer").set_battery(not ac)

        gears.timer.start_new(first and 3 or 0.1, function()
            local panel
            for sc in screen do for name in pairs(sc.outputs or {}) do
                if name:match("^eDP") then panel = name end
            end end
            if not panel then return false end
            awful.spawn.easy_async({ "xrandr", "--output", panel, "--mode", "2560x1600", "--rate", rate }, function(_, _, _, code)
                if not first and code == 0 then
                    naughty.notify({ title = "display: " .. rate .. "hz", text = ac and "charger plugged in" or "on battery", timeout = 2 })
                end
            end)
            return false
        end)
    end
end
cpu:buttons(gears.table.join(awful.button({}, 1, function() awful.spawn(monitor) end)))

local mode = textw()
local fans = textw()
local asus_hwmon
for i = 0, 15 do
    if (read("/sys/class/hwmon/hwmon" .. i .. "/name") or ""):match("^asus%s*$") then asus_hwmon = "/sys/class/hwmon/hwmon" .. i end
end
local mode_names = { quiet = "quiet", balanced = "balanced", performance = "turbo", ["low-power"] = "quiet" }
local function mode_update()
    local p = (read("/sys/firmware/acpi/platform_profile") or "?"):gsub("%s", "")
    mode:set_markup(kv("mode", mode_names[p] or p, p == "performance" and c.accent2 or c.fg))
    if asus_hwmon then
        local f1 = tonumber(read(asus_hwmon .. "/fan1_input") or "") or 0
        local f2 = tonumber(read(asus_hwmon .. "/fan2_input") or "") or 0
        local function k(r) return r >= 1000 and string.format("%.1fk", r / 1000) or tostring(r) end
        fans:set_markup(kv("fan", k(f1) .. "/" .. k(f2)))
    end
end

local function mode_next()
    awful.spawn.easy_async_with_shell([[
        if command -v asusctl >/dev/null && systemctl is-active -q asusd; then asusctl profile next
        else case "$(powerprofilesctl get)" in
            power-saver) powerprofilesctl set balanced ;; balanced) powerprofilesctl set performance ;;
            *) powerprofilesctl set power-saver ;; esac
        fi]], function()
        gears.timer.start_new(0.4, function()
            mode_update()
            local p = (read("/sys/firmware/acpi/platform_profile") or "?"):gsub("%s", "")
            naughty.notify({ title = "mode: " .. (mode_names[p] or p), timeout = 1.5 })
            return false
        end)
    end)
end

local gpu = textw()
local GPU_PCI = "/sys/bus/pci/devices/0000:01:00.0"
local function tick_gpu()

    if (read("/sys/devices/platform/asus-nb-wmi/dgpu_disable") or ""):match("1") or not read(GPU_PCI .. "/vendor") then
        gpu:set_markup(kv("gpu", "off", c.dim)); return
    end

    if not gears.filesystem.dir_readable(GPU_PCI .. "/driver") then gpu:set_markup(kv("gpu", "no driver", c.red)); return end

    local status = read(GPU_PCI .. "/power/runtime_status") or ""
    if status:match("active") then gpu:set_markup(kv("gpu", "awake", c.accent2))
    else gpu:set_markup(kv("gpu", "sleep", c.dim)) end
end

local function rog_center()
    awful.spawn(os.getenv("HOME") .. "/.local/bin/rog-menu")
end
for _, w in ipairs({ mode, fans }) do
    w:buttons(gears.table.join(awful.button({}, 1, mode_next), awful.button({}, 3, rog_center)))
end
mem:buttons(cpu:buttons())

local disk = textw()
local net  = textw()
local function tick_slow()
    bat_limit = nil
    awful.spawn.easy_async({ "df", "--output=pcent", "/" }, function(out)
        local used = tonumber(out:match("(%d+)%%")) or 0
        disk.visible = used >= 80
        disk:set_markup(kv("disk", used .. "%", used >= 90 and c.red or c.fg))
    end)
    awful.spawn.easy_async({ "nmcli", "-t", "-f", "active,ssid", "dev", "wifi" }, function(out)
        local ssid = (("\n" .. out):match("\nyes:([^\n]*)") or ""):gsub("\\:", ":")
        ssid = trunc(ssid, 12)
        local up = (read("/sys/class/net/wlo1/operstate") or ""):match("up")
        net:set_markup(kv("wifi", ssid ~= "" and ssid or (up and "up" or "down"), up and c.fg or c.red))
    end)
end

do
    local n = 0
    gears.timer({ timeout = 2, autostart = true, call_now = true, callback = function()
        tick_stats()
        if n % 2 == 0 then mode_update() end
        if n % 3 == 0 then tick_gpu() end
        if n % 30 == 0 then tick_slow() end
        n = n + 1
    end })
end

local playing = textw()
playing:set_markup(kv("playing", "nothing", c.dim))
follow({ "playerctl", "--follow", "metadata", "--format", "{{artist}} - {{title}}" }, "^playerctl --follow metadata", function(line)
    line = line:gsub("^%s*-%s*", ""):gsub("%s+$", "")
    line = trunc(line, 60)
    playing:set_markup(kv("playing", line ~= "" and line or "nothing", line ~= "" and c.fg or c.dim))
end)

playing:buttons(gears.table.join(
    awful.button({}, 1, function() require("visualizer").toggle_card(mouse.screen) end),
    awful.button({}, 3, sh("playerctl play-pause"))))

local clock = wibox.widget.textclock("<span foreground='" .. c.fg .. "'>%H:%M - %d.%m.%Y</span>", 60)

local powerbtn = wibox.widget.textbox(color(c.accent, "power"))
powerbtn:buttons(gears.table.join(awful.button({}, 1, function() powermenu:toggle() end)))

local function spaced(s, ...)
    local l = wibox.layout.fixed.horizontal()
    l.spacing = dpi(18, s)
    for _, w in ipairs({ ... }) do l:add(w) end
    return wibox.container.margin(l, dpi(10, s), dpi(10, s))
end

local help_lines = {
    { "Super + Enter",        "terminal" },
    { "Super + B",            "browser" },
    { "Super + S",            "spotify" },
    { "Super + E",            "files (yazi)" },
    { "Super + Space",        "search & open apps" },
    { "Super + Q",            "close window" },
    { "Super + F",            "fullscreen window" },
    { "Super + Tab",          "layout: side-by-side / one big / free" },
    { "Super + arrows",       "move focus between windows" },
    { "Super + Shift + arrows", "move the window" },
    { "Super + 1..5",         "go to workspace" },
    { "Super + Shift + 1..5", "send window to workspace" },
    { "Super + drag",         "move window  (right-drag: resize)" },
    { "Super + M",            "fix monitors (after plugging in)" },
    { "Super+P / Fn+F5 / ROG", "performance mode: quiet / balanced / turbo" },
    { "Fn + F4",              "keyboard lighting effect" },
    { "Super + Shift + P",    "rog menu: modes, fans, battery limit" },
    { "Super + Esc",          "power menu" },
    { "Super + L",            "lock screen" },
    { "Alt + Tab",            "back to the previous window" },
    { "Super + W",            "pick any window (search)" },
    { "Super + `",            "drop-down terminal (show / hide)" },
    { "Super + O",            "send window to the other monitor" },
    { "Super + N / Shift+N",  "minimise / bring back" },
    { "Super + T",            "keep window on top" },
    { "Super + Ctrl + Space", "float / tile this window" },
    { "Super + Ctrl + Enter", "make this the main window" },
    { "Super + Ctrl + arrows", "resize tiled windows" },
    { "Super + U",            "jump to the window asking for attention" },
    { "Super + V",            "clipboard history" },
    { "Super + Backspace",    "clear notifications" },
    { "Super + Shift + R",    "reload desktop" },
    { "Print",                "screenshot -> saved + clipboard" },
    { "Shift+Print / Super+Shift+S", "screenshot area -> clipboard" },
    { "Super + /",            "this help" },
}
local help_text = { color(c.accent, "  navi :: keys") .. "\n" }
for _, l in ipairs(help_lines) do
    help_text[#help_text + 1] = "  " .. color(c.accent2, string.format("%-28s", l[1])) .. color(c.fg, l[2])
end
help_text[#help_text + 1] = "\n" .. color(c.dim, "  press any key to close")

local help = awful.popup {
    widget = { widget = wibox.container.margin, margins = dpi(16),
               { widget = wibox.widget.textbox, markup = table.concat(help_text, "\n") } },
    ontop = true, visible = false, bg = c.black,
    border_width = dpi(2), border_color = c.accent,
    placement = awful.placement.centered,
}

local function show_help()
    help.screen = awful.screen.focused()
    help.visible = true
    awful.placement.centered(help, { parent = help.screen })
    keygrabber.run(function(_, _, event)
        if event == "release" then return end
        keygrabber.stop(); help.visible = false
    end)
end
help:buttons(gears.table.join(awful.button({}, 1, function() keygrabber.stop(); help.visible = false end)))

local function set_wallpaper(s)
    if gears.filesystem.file_readable(beautiful.wallpaper) then
        gears.wallpaper.maximized(beautiful.wallpaper, s, false)
    else
        gears.wallpaper.set(c.black)
    end
end
screen.connect_signal("property::geometry", set_wallpaper)

local function screen_dpi(s)
    for _, o in pairs(s.outputs or {}) do
        if o.mm_width and o.mm_width > 0 then
            return (s.geometry.width / (o.mm_width / 25.4)) >= 150 and DPI or 96
        end
    end
    return DPI
end

local taglist_buttons = gears.table.join(
    awful.button({}, 1, function(t) t:view_only() end),
    awful.button({}, 4, function(t) awful.tag.viewprev(t.screen) end),
    awful.button({}, 5, function(t) awful.tag.viewnext(t.screen) end))

awful.screen.connect_for_each_screen(function(s)
    beautiful.xresources.set_dpi(screen_dpi(s), s)
    set_wallpaper(s)
    awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.layouts[1])

    local function mark(self, t)
        self:get_children_by_id("line")[1].color = t.selected and c.accent or c.black
    end
    s.tags_widget = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.noempty,
        buttons = taglist_buttons,
        layout  = { layout = wibox.layout.fixed.horizontal, spacing = dpi(4, s) },
        widget_template = {
            {
                {
                    { id = "text_role", widget = wibox.widget.textbox },
                    left = dpi(10, s), right = dpi(10, s),
                    widget = wibox.container.margin,
                },
                bottom = dpi(3, s), color = c.black, id = "line",
                widget = wibox.container.margin,
            },
            id = "background_role",
            widget = wibox.container.background,
            create_callback = function(self, t) mark(self, t) end,
            update_callback = function(self, t) mark(self, t) end,
        },
    }

    local h = dpi(22, s)
    s.top = awful.wibar({ position = "top", screen = s, height = h })
    local unstick = gears.table.join(awful.button({}, 1, function()
        if keygrabber.isrunning() then keygrabber.stop() end
        help.visible = false
    end))
    s.top:buttons(unstick)
    s.top:setup {
        layout = wibox.layout.align.horizontal,
        expand = "none",
        spaced(s, audio, mem, cpu, bat),
        clock,
        { layout = wibox.layout.fixed.horizontal, spaced(s, disk, gpu, mode, fans, net),
          s == screen.primary and wibox.widget.systray() or wibox.widget.textbox("") },
    }

    s.bottom = awful.wibar({ position = "bottom", screen = s, height = h })
    s.bottom:buttons(unstick)
    s.bottom:setup {
        layout = wibox.layout.align.horizontal,
        expand = "none",
        spaced(s, playing),
        s.tags_widget,
        spaced(s, powerbtn),
    }
end)

root.buttons(gears.table.join(
    awful.button({}, 3, function() powermenu:toggle() end)))

local function k(mods, key, fn) return awful.key(mods, key, fn) end
local function focus_dir(d) return function()
    awful.client.focus.global_bydirection(d)
    if client.focus then client.focus:raise() end
end end
local function cycle_layout()
    awful.layout.inc(1)
    local name = awful.layout.getname()
    local nice = ({ tile = "side by side", max = "one big window", floating = "free windows" })[name] or name
    naughty.notify({ text = "layout: " .. nice, timeout = 1 })
end

local BL_MIN = tostring(math.max(1, math.floor((tonumber(read("/sys/class/backlight/intel_backlight/max_brightness") or "") or 100) / 100)))
local function brightness(arg) return function()
    awful.spawn.easy_async({ "brightnessctl", "-m", "-d", "intel_backlight", "-n" .. BL_MIN, "set", arg }, function(out)
        osd_show("light", tonumber(out:match(",(%d+)%%")) or 0)
    end)
end end

local scratch, scratch_pending
local function scratch_place(cl)
    local wa = cl.screen.workarea
    cl:geometry({ x = wa.x + math.floor(wa.width * 0.15), y = wa.y,
                  width = math.floor(wa.width * 0.7), height = math.floor(wa.height * 0.45) })
end
local function scratch_toggle()
    if scratch and scratch.valid then
        local s = awful.screen.focused()
        if scratch.hidden or scratch.screen ~= s or not scratch:isvisible() then
            scratch.hidden = false
            scratch:move_to_screen(s)
            if s.selected_tag then scratch:move_to_tag(s.selected_tag) end
            scratch_place(scratch)

            gears.timer.delayed_call(function()
                if scratch and scratch.valid then scratch:emit_signal("request::activate", "scratchpad", { raise = true }) end
            end)
        else
            scratch.hidden = true
        end
    elseif not scratch_pending then
        scratch_pending = true
        gears.timer.start_new(5, function() scratch_pending = false; return false end)
        awful.spawn(terminal .. " --class scratchpad")
    end
end

local function to_next_screen()
    local cl = client.focus; if not cl then return end
    cl:move_to_screen()
    if cl.floating then awful.placement.centered(cl, { honor_workarea = true }) end
end

local function restore()
    local cl = awful.client.restore()
    if cl then cl:emit_signal("request::activate", "key.unminimize", { raise = true }) end
end

local globalkeys = gears.table.join(
    k({ super }, "Return", function() awful.spawn(terminal) end),
    k({ super }, "b",      function() awful.spawn(browser) end),
    k({ super }, "s",      function() awful.spawn(music) end),
    k({ super }, "e",      function()
        if has("yazi") then awful.spawn(files)
        else naughty.notify({ title = "yazi isn't installed", text = "install yazi to use the file manager" }) end
    end),
    k({ super }, "space",  function() awful.spawn(launcher) end),
    k({ super }, "Tab",    cycle_layout),
    k({ super }, "slash",  show_help),
    k({ super }, "F1",     show_help),
    k({ super }, "Escape", function() powermenu:show() end),
    k({ super }, "m",      sh(conf .. "screens.sh")),
    k({ super }, "p",      mode_next),
    k({ super, "Shift" }, "p", rog_center),
    k({}, "XF86Launch4",   mode_next),
    k({}, "XF86Launch3",   sh("asusctl aura effect --next-mode")),
    k({ super, "Shift" }, "r", awesome.restart),

    k({ super }, "Left",  focus_dir("left")),
    k({ super }, "Right", focus_dir("right")),
    k({ super }, "Up",    focus_dir("up")),
    k({ super }, "Down",  focus_dir("down")),

    k({}, "Print",            sh("mkdir -p ~/Pictures/screenshots && f=~/Pictures/screenshots/$(date +%F_%H-%M-%S).png && maim \"$f\" && xclip -selection clipboard -t image/png -i \"$f\" && notify-send 'screenshot saved + copied'")),
    k({ "Shift" }, "Print",   sh("maim -s | xclip -selection clipboard -t image/png")),
    k({}, "XF86AudioRaiseVolume", vol_up),
    k({}, "XF86AudioLowerVolume", vol_down),
    k({}, "XF86AudioMute",        vol_mute),
    k({}, "XF86AudioPlay",        sh("playerctl play-pause")),
    k({}, "XF86AudioNext",        sh("playerctl next")),
    k({}, "XF86AudioPrev",        sh("playerctl previous")),
    k({}, "XF86MonBrightnessUp",   brightness("5%+")),
    k({}, "XF86MonBrightnessDown", brightness("5%-")),

    k({ "Mod1" }, "Tab",       function()
        awful.client.focus.history.previous()
        if client.focus then client.focus:raise() end
    end),
    k({ super }, "w",          function() awful.spawn("rofi -show window") end),
    k({ super }, "grave",      scratch_toggle),
    k({ super }, "l",          function() awful.spawn(os.getenv("HOME") .. "/.local/bin/navi-lock") end),
    k({ super }, "o",          to_next_screen),
    k({ super }, "u",          awful.client.urgent.jumpto),
    k({ super, "Shift" }, "n", restore),
    k({ super }, "BackSpace",  function() naughty.destroy_all_notifications() end),
    k({ super, "Shift" }, "s", sh("maim -s | xclip -selection clipboard -t image/png")),
    k({ super }, "v",          function()
        if has("clipmenu") then awful.spawn.with_shell("CM_LAUNCHER=rofi clipmenu")
        else naughty.notify({ title = "clipboard history isn't installed", text = "install clipmenu" }) end
    end),
    k({ super, "Control" }, "Right", function() awful.tag.incmwfact( 0.05) end),
    k({ super, "Control" }, "Left",  function() awful.tag.incmwfact(-0.05) end),
    k({ super, "Control" }, "Up",    function() awful.client.incwfact( 0.1) end),
    k({ super, "Control" }, "Down",  function() awful.client.incwfact(-0.1) end)
)
for i = 1, 5 do
    globalkeys = gears.table.join(globalkeys,
        k({ super }, tostring(i), function()
            local t = awful.screen.focused().tags[i]; if t then t:view_only() end
        end),
        k({ super, "Shift" }, tostring(i), function()
            local t = client.focus and client.focus.screen.tags[i]
            if t then client.focus:move_to_tag(t) end
        end))
end
root.keys(globalkeys)

local clientkeys = gears.table.join(
    k({ super }, "q", function(cl) cl:kill() end),
    k({ super }, "f", function(cl) cl.fullscreen = not cl.fullscreen; cl:raise() end),
    k({ super }, "n", function(cl) cl.minimized = true end),
    k({ super }, "t", function(cl) cl.ontop = not cl.ontop
        naughty.notify({ text = "always on top: " .. (cl.ontop and "on" or "off"), timeout = 1 }) end),
    k({ super, "Control" }, "space", function(cl) awful.client.floating.toggle(cl)
        if cl.floating then awful.placement.centered(cl, { honor_workarea = true }) end end),
    k({ super, "Control" }, "Return", function(cl) cl:swap(awful.client.getmaster()) end),
    k({ super, "Shift" }, "Left",  function(cl) awful.client.swap.global_bydirection("left", cl) end),
    k({ super, "Shift" }, "Right", function(cl) awful.client.swap.global_bydirection("right", cl) end),
    k({ super, "Shift" }, "Up",    function(cl) awful.client.swap.global_bydirection("up", cl) end),
    k({ super, "Shift" }, "Down",  function(cl) awful.client.swap.global_bydirection("down", cl) end)
)

local clientbuttons = gears.table.join(
    awful.button({}, 1, function(cl) cl:emit_signal("request::activate", "mouse_click", { raise = true }) end),
    awful.button({ super }, 1, function(cl)
        cl:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.move(cl)
    end),
    awful.button({ super }, 3, function(cl)
        cl:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.resize(cl)
    end))

awful.rules.rules = {
    { rule = {},
      properties = {
          border_width = beautiful.border_width,
          border_color = beautiful.border_normal,
          focus = awful.client.focus.filter,
          raise = true,
          keys = clientkeys,
          buttons = clientbuttons,
          screen = awful.screen.preferred,
          placement = awful.placement.no_overlap + awful.placement.no_offscreen,
          size_hints_honor = false,
          titlebars_enabled = true,
      } },
    { rule_any = { type = { "dialog" }, class = { "Pavucontrol", "Nm-connection-editor" }, role = { "pop-up" } },
      properties = { floating = true, placement = awful.placement.centered } },

    { rule = { class = "feh" },
      properties = { floating = true, screen = awful.screen.focused },
      callback = function(cl)

          local wa = cl.screen.workarea
          local k = math.min(1, wa.width * 0.85 / cl.width, wa.height * 0.85 / cl.height)
          cl:geometry({ width = math.floor(cl.width * k), height = math.floor(cl.height * k) })
          awful.placement.centered(cl, { honor_workarea = true })
      end },

    { rule_any = { role = { "GtkFileChooserDialog" }, class = { "Xdg-desktop-portal-gtk", "filepicker" },
                   name = { "Open File", "Open Folder", "Save File", "Open Files" } },
      properties = { floating = true, titlebars_enabled = true },
      callback = function(cl)
          local wa = cl.screen.workarea
          cl:geometry({ width = math.floor(wa.width * 0.6), height = math.floor(wa.height * 0.7) })
          awful.placement.centered(cl, { honor_workarea = true })
      end },

    { rule = { class = "scratchpad" },
      properties = { floating = true, ontop = true, skip_taskbar = true, titlebars_enabled = false,
                     border_width = beautiful.border_width },
      callback = function(cl)
          scratch, scratch_pending = cl, false
          scratch_place(cl)
          if awesome.startup then cl.hidden = true; return end
          gears.timer.delayed_call(function() if cl.valid then cl:emit_signal("request::activate", "scratchpad", { raise = true }) end end)
      end },
}

client.connect_signal("request::titlebars", function(cl)
    cl.navi_titlebar = true
    local name = wibox.widget.textbox()
    local function upd() name.text = (cl.class or cl.name or ""):lower() end
    upd(); cl:connect_signal("property::class", upd)
    awful.titlebar(cl, { size = dpi(18, cl.screen) }):setup {
        { name, left = dpi(6), widget = wibox.container.margin },
        nil, nil,
        buttons = gears.table.join(
            awful.button({}, 1, function() cl:emit_signal("request::activate", "titlebar", { raise = true }); awful.mouse.client.move(cl) end),
            awful.button({}, 3, function() cl:emit_signal("request::activate", "titlebar", { raise = true }); awful.mouse.client.resize(cl) end)),
        layout = wibox.layout.align.horizontal,
    }
end)

client.connect_signal("manage", function(cl)
    if awesome.startup and not cl.size_hints.user_position and not cl.size_hints.program_position then
        awful.placement.no_offscreen(cl)
    end
end)
client.connect_signal("mouse::enter", function(cl) cl:emit_signal("request::activate", "mouse_enter", { raise = false }) end)
client.connect_signal("focus",   function(cl) cl.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(cl) cl.border_color = beautiful.border_normal end)

client.connect_signal("property::fullscreen", function(cl)
    if cl.fullscreen then awful.titlebar.hide(cl) elseif cl.navi_titlebar then awful.titlebar.show(cl) end
end)

awesome.register_xproperty("_NAVI_STARTED", "boolean")
local first_start = not awesome.get_xproperty("_NAVI_STARTED")
awesome.set_xproperty("_NAVI_STARTED", true)

awful.spawn.with_shell([[
    command -v udiskie   >/dev/null && ! pgrep -x udiskie >/dev/null && udiskie &
    command -v xss-lock  >/dev/null && ! pgrep -x xss-lock >/dev/null && xss-lock --transfer-sleep-lock -- ~/.local/bin/navi-lock --nofork &
    command -v clipmenud >/dev/null && ! pgrep -f 'bin/clipmenud$' >/dev/null && clipmenud &
    pgrep -x picom >/dev/null || picom -b]])
if first_start then
    awful.spawn.with_shell(conf .. "screens.sh")
    awful.spawn.with_shell("xrdb -merge ~/.Xresources 2>/dev/null")
end

require("visualizer").init()

if first_start then awful.spawn.easy_async({ "journalctl", "-k", "-b", "-q", "--no-pager", "-g", "Machine Check", "-o", "cat" }, function(out)
    local n = select(2, out:gsub("\n", ""))
    if n > 0 then
        naughty.notify({ timeout = 0, bg = c.black, fg = c.red, border_color = c.red,
            title = "cpu reported " .. n .. " hardware error" .. (n == 1 and "" or "s") .. " this boot",
            text = "details: journalctl -k -b -p err\nhistory: sudo ras-mc-ctl db --errors" })
    end
end)
naughty.notify({ title = "present day. present time.", text = "press Super + / to see your keys", timeout = 5 }) end
