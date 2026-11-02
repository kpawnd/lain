local gears     = require("gears")
local awful     = require("awful")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local lgi       = require("lgi")
local cairo     = lgi.cairo
local Pango     = lgi.Pango
local PangoCairo = lgi.PangoCairo

local c   = beautiful.c
local dpi = beautiful.xresources.apply_dpi

local PLAYER    = "spotify"
local CAVA_CONF = gears.filesystem.get_configuration_dir() .. "../cava/navi"
local LOGO      = os.getenv("HOME") .. "/.config/fastfetch/navi.txt"
local ART_DIR   = gears.filesystem.get_cache_dir() .. "art/"
local NBARS     = 48
local FONT      = "JetBrainsMono Nerd Font"
local ORB_X     = 0.27
local ORB_Y     = 0.47
local ORB_R     = 0.27
local LOGO_DIM  = "#385475"

local M = { boxes = {} }
local levels, peaks, pvel = {}, {}, {}
for i = 1, NBARS do levels[i], peaks[i], pvel[i] = 0, 0, 0 end
local bass, kick = 0, 0
local WEIGHT = {}
for i = 1, NBARS do WEIGHT[i] = 1.25 - 0.55 * ((i - 1) / (NBARS - 1)) ^ 0.7 end

local state = { status = "Stopped", title = "", artist = "", album = "", art = nil, length = 0, pos = 0 }

local function esc(s) return gears.string.xml_escape(s or "") end
local function span(col, text, extra)
    return "<span foreground='" .. col .. "'" .. (extra or "") .. ">" .. esc(text) .. "</span>"
end
local function clock(sec)
    sec = math.max(0, math.floor(sec or 0))
    return string.format("%d:%02d", sec // 60, sec % 60)
end
local function rgb(hex)
    local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

local AR, AG, AB    = rgb(c.accent)
local A2R, A2G, A2B = rgb(c.accent2)
local RR, RG, RB    = rgb(c.red)
local FR, FG, FB    = rgb(c.fg)
local LDR, LDG, LDB = rgb(LOGO_DIM)

local logo_layers
local function read_logo()
    if logo_layers then return logo_layers end
    local f = io.open(LOGO)
    local bright, dim = {}, {}
    if f then
        for line in f:lines() do
            local b, d, col = {}, {}, "2"
            local i = 1
            while i <= #line do
                local ch = line:sub(i, i)
                if ch == "$" and line:sub(i + 1, i + 1):match("%d") then
                    col = line:sub(i + 1, i + 1); i = i + 2
                else
                    b[#b + 1] = col == "1" and ch or " "
                    d[#d + 1] = col == "1" and " " or ch
                    i = i + 1
                end
            end
            bright[#bright + 1] = table.concat(b)
            dim[#dim + 1] = table.concat(d)
        end
        f:close()
    end
    logo_layers = { bright = table.concat(bright, "\n"), dim = table.concat(dim, "\n") }
    return logo_layers
end

local function logo_surface(text, width)
    local probe = cairo.ImageSurface.create("ARGB32", 1, 1)
    local layout = PangoCairo.create_layout(cairo.Context.create(probe))
    layout:set_font_description(Pango.FontDescription.from_string(FONT .. " Bold 20"))
    layout:set_text(text, -1)
    local _, ext = layout:get_pixel_extents()
    local sc = width / math.max(1, ext.width)
    local w, h = math.ceil(ext.width * sc), math.ceil(ext.height * sc)
    local surf = cairo.ImageSurface.create("ARGB32", w, h)
    local cr = cairo.Context.create(surf)
    cr:scale(sc, sc)
    cr:translate(-ext.x, -ext.y)
    cr:set_source_rgba(1, 1, 1, 1)
    PangoCairo.update_layout(cr, layout)
    PangoCairo.show_layout(cr, layout)
    surf:flush()
    return surf, w, h
end

local NSPOKE = NBARS * 2
local function band(k) return k <= NBARS and k or (NSPOKE - k + 1) end

local function make_orb(s, size)
    local orb = wibox.widget.base.make_widget()
    local cx, cy = size / 2, size / 2
    local R      = size / 2
    local logo_w = R * 0.84
    local base   = R * 0.52
    local reach  = R * 0.94 - base
    local step   = math.max(3, dpi(7, s))
    local dotr   = math.max(1, dpi(1.4, s))
    local split  = math.max(2, dpi(4, s))
    local outer  = R * 0.985
    local dash   = { 0, math.max(4, dpi(10, s)) }
    local spin   = 0

    local layers = read_logo()
    local lb, lw, lh = logo_surface(layers.bright, logo_w)
    local ld         = logo_surface(layers.dim, logo_w)

    local cosk, sink = {}, {}
    for k = 1, NSPOKE do
        local a = -math.pi / 2 + (k - 0.5) * 2 * math.pi / NSPOKE
        cosk[k], sink[k] = math.cos(a), math.sin(a)
    end

    local function paint_logo(cr, surf, dx, sc)
        cr:save()
        cr:translate(cx + dx, cy)
        cr:scale(sc, sc)
        cr:translate(-lw / 2, -lh / 2)
        cr:mask_surface(surf, 0, 0)
        cr:restore()
    end

    function orb:fit() return size, size end
    function orb:draw(_, cr)

        if bass > 0.01 then
            local halo = cairo.RadialPattern.create(cx, cy, R * 0.2, cx, cy, R)
            halo:add_color_stop_rgba(0,   AR, AG, AB, 0.05 + 0.20 * bass)
            halo:add_color_stop_rgba(0.5, AR, AG, AB, 0.02 + 0.07 * bass)
            halo:add_color_stop_rgba(1,   AR, AG, AB, 0)
            cr:set_source(halo)
            cr:paint()
        end

        spin = (spin + 0.35 + 2.5 * bass) % 1000
        cr:set_line_cap("ROUND")
        cr:set_line_width(dotr * 2)
        cr:set_dash(dash, #dash, spin)
        cr:set_source_rgba(LDR, LDG, LDB, 0.55 + 0.4 * bass)
        cr:arc(cx, cy, outer, 0, 2 * math.pi)
        cr:stroke()
        cr:set_dash({}, 0, 0)

        cr:push_group()
        for pass = 1, 2 do
            if pass == 1 then cr:set_source_rgba(LDR, LDG, LDB, 1) else cr:set_source_rgba(AR, AG, AB, 1) end
            for k = 1, NSPOKE do
                local len = levels[band(k)] * reach
                local n = math.floor(len / step)

                local from = pass == 1 and 0 or math.floor(n * 0.6) + 1
                local to   = pass == 1 and math.floor(n * 0.6) or n
                for d = from, to do
                    local r = base + d * step
                    cr:move_to(cx + cosk[k] * r + dotr, cy + sink[k] * r)
                    cr:arc(cx + cosk[k] * r, cy + sink[k] * r, dotr, 0, 2 * math.pi)
                end
            end
            cr:fill()
        end
        local group = cr:pop_group()
        if kick > 0.03 then
            local off = split * (1 + 2 * kick)
            group:set_matrix(cairo.Matrix.create_translate(off, 0))
            cr:set_source_rgba(RR, RG, RB, 0.5 * kick)
            cr:mask(group)
            group:set_matrix(cairo.Matrix.create_translate(-off, 0))
            cr:set_source_rgba(A2R, A2G, A2B, 0.4 * kick)
            cr:mask(group)
            group:set_matrix(cairo.Matrix.create_translate(0, 0))
        end
        cr:set_source(group)
        cr:paint()

        cr:set_source_rgba(A2R, A2G, A2B, 0.95)
        for k = 1, NSPOKE do
            local p = peaks[band(k)]
            if p > 0.04 then
                local r = base + p * reach + step
                cr:move_to(cx + cosk[k] * r + dotr * 1.5, cy + sink[k] * r)
                cr:arc(cx + cosk[k] * r, cy + sink[k] * r, dotr * 1.5, 0, 2 * math.pi)
            end
        end
        cr:fill()

        local sc = 1 + 0.06 * bass
        cr:set_source_rgba(LDR, LDG, LDB, 0.95)
        paint_logo(cr, ld, 0, sc)
        if kick > 0.03 then
            local off = split * (1 + 2 * kick)
            cr:set_source_rgba(RR, RG, RB, 0.7 * kick)
            paint_logo(cr, lb, off, sc)
            cr:set_source_rgba(A2R, A2G, A2B, 0.6 * kick)
            paint_logo(cr, lb, -off, sc)
        end
        local glow = state.status == "Playing" and (0.7 + 0.3 * bass) or 0.55
        cr:set_source_rgba(AR + (FR - AR) * bass * 0.6, AG + (FG - AG) * bass * 0.6, AB + (FB - AB) * bass * 0.6, glow)
        paint_logo(cr, lb, 0, sc)
    end
    return orb
end

local function covered(b)
    local g = b.box:geometry()
    for _, cl in ipairs(b.s.clients) do
        if not cl.minimized then
            local w = cl:geometry()
            if w.x < g.x + g.width and w.x + w.width > g.x and w.y < g.y + g.height and w.y + w.height > g.y then
                return true
            end
        end
    end
    return false
end
local on_battery = false
function M.set_battery(v)
    if on_battery == v then return end
    on_battery = v

    if M.status_refresh then M.status_refresh() end
end

local cover_dirty = true
local function dirty() cover_dirty = true end
for _, sig in ipairs({ "manage", "unmanage", "property::geometry", "property::minimized",
                       "property::hidden", "tagged", "untagged" }) do
    client.connect_signal(sig, dirty)
end
tag.connect_signal("property::selected", dirty)
local function redraw(force)
    if cover_dirty then
        cover_dirty = false
        for _, b in pairs(M.boxes) do b.covered = covered(b) end
    end
    for _, b in pairs(M.boxes) do
        if b.box.visible and (force or not b.covered) then b.orb:emit_signal("widget::redraw_needed") end
    end
end

local GRAV = 0.0025
local function step()
    local lo = 0
    for i = 1, 5 do lo = lo + levels[i] end
    lo = lo / 5
    if lo > bass + 0.12 and lo > 0.6 then kick = math.min(1, kick + 0.9) end
    bass = bass * 0.55 + lo * 0.45
    kick = kick * 0.78
    for i = 1, NBARS do
        if levels[i] >= peaks[i] then peaks[i], pvel[i] = levels[i], 0
        else pvel[i] = pvel[i] + GRAV; peaks[i] = math.max(0, peaks[i] - pvel[i]) end
    end
    redraw()
end

local cava_pid
local cava_start
local decay = gears.timer {
    timeout = 1 / 40,
    callback = function(t)
        local any = false
        for i = 1, NBARS do
            levels[i] = levels[i] * 0.84
            if levels[i] > 0.004 then any = true else levels[i] = 0 end
            if peaks[i] > 0.004 then any = true end
        end
        step()
        if not any then bass, kick = 0, 0; redraw(true); t:stop() end
    end,
}

function cava_start()
    if cava_pid then return end
    decay:stop()
    local pid
    pid = awful.spawn.with_line_callback({ "cava", "-p", CAVA_CONF }, {
        stdout = function(line)
            local i = 0
            for n in line:gmatch("(%d+)") do
                i = i + 1
                if i > NBARS then break end
                levels[i] = math.min(1, (tonumber(n) / 1000) ^ 0.85 * WEIGHT[i])
            end
            step()
        end,
        exit = function()
            if cava_pid == nil or cava_pid ~= pid then return end
            cava_pid = nil
            if state.status == "Playing" then
                gears.timer.start_new(2, function() if state.status == "Playing" then cava_start() end; return false end)
            end
        end,
    })
    if type(pid) == "number" then cava_pid = pid end
end

local function cava_stop()
    if cava_pid then awesome.kill(cava_pid, 15); cava_pid = nil end
    decay:again()
end

awesome.connect_signal("exit", function() if cava_pid then awesome.kill(cava_pid, 15) end end)

local card = {}
card.label    = wibox.widget { widget = wibox.widget.textbox, font = FONT .. " 8" }
card.title    = wibox.widget { widget = wibox.widget.textbox, font = FONT .. " 12", ellipsize = "end", wrap = "char" }
card.sub      = wibox.widget { widget = wibox.widget.textbox, font = FONT .. " 9", ellipsize = "end", wrap = "char" }
card.time     = wibox.widget { widget = wibox.widget.textbox, font = FONT .. " 8" }
card.art      = wibox.widget { widget = wibox.widget.imagebox, resize = true }
card.progress = wibox.widget {
    widget = wibox.widget.progressbar, max_value = 1, value = 0,
    color = c.accent, background_color = c.line,
}
card.artbox = wibox.widget { card.art, widget = wibox.container.constraint, strategy = "exact" }
card.progbox = wibox.widget { card.progress, widget = wibox.container.constraint, strategy = "exact" }
card.popup = awful.popup {
    widget = {
        {
            card.artbox,
            {
                card.label, card.title, card.sub,
                { { card.progbox, valign = "center", widget = wibox.container.place },
                  card.time, layout = wibox.layout.fixed.horizontal, id = "row" },
                layout = wibox.layout.fixed.vertical, id = "text",
            },
            layout = wibox.layout.fixed.horizontal, id = "body",
        },
        widget = wibox.container.margin, id = "pad",
    },
    border_width = 1, border_color = c.accent,
    bg = c.black, ontop = true, visible = false,
    placement = function(d) awful.placement.bottom_left(d, { honor_workarea = true, margins = dpi(8, d.screen) }) end,
}
card.popup:buttons(gears.table.join(awful.button({}, 1, function() card.popup.visible = false end)))

local function size_card(s)
    local p = card.popup.widget
    p.margins = dpi(12, s)
    p:get_children_by_id("body")[1].spacing = dpi(12, s)
    p:get_children_by_id("text")[1].spacing = dpi(2, s)
    p:get_children_by_id("row")[1].spacing = dpi(10, s)
    card.artbox.width, card.artbox.height = dpi(72, s), dpi(72, s)
    card.progbox.width, card.progbox.height = dpi(200, s), math.max(1, dpi(2, s))
    card.title.forced_width, card.sub.forced_width = dpi(300, s), dpi(300, s)
    card.popup.border_width = math.max(1, dpi(1, s))
end

local poll
local function update_card()
    if state.title == "" then
        card.label:set_markup(span(c.dim, "nothing playing"))
        card.title:set_markup(span(c.dim, "open spotify with Super + S"))
        card.sub:set_markup(""); card.time:set_markup("")
        card.art.image = nil; card.artbox.visible = false
        card.progress.value = 0
        return
    end
    local playing = state.status == "Playing"
    card.label:set_markup(span(playing and c.accent or c.dim, playing and "▶ " or "⏸ ")
        .. span(c.dim, playing and "now playing" or "paused") .. span(c.line, "  ─  ") .. span(c.dim, "spotify"))
    card.title:set_markup(span(c.fg, state.title, " font_weight='bold'"))
    local sub = state.artist
    if state.album ~= "" and state.album ~= state.title then sub = sub .. "  ·  " .. state.album end
    card.sub:set_markup(span(c.accent2, sub))
    card.art.image = state.art
    card.artbox.visible = state.art ~= nil
    card.progress.max_value = math.max(state.length, 1)
    card.progress.value = state.pos
    card.time:set_markup(span(c.dim, clock(state.pos) .. " / " .. clock(state.length)))
end

function M.toggle_card(s)
    if card.popup.visible then card.popup.visible = false; return end
    s = s or awful.screen.focused()
    card.popup.screen = s
    size_card(s)
    update_card()
    card.popup.visible = true
    poll:emit_signal("timeout")
    awful.placement.bottom_left(card.popup, { honor_workarea = true, margins = dpi(8, s), parent = s })
end

local function update_all()
    local show = state.status ~= "Stopped" and state.title ~= "" and not on_battery
    for _, b in pairs(M.boxes) do b.box.visible = show end
    if card.popup.visible then update_card() end
    redraw(true)
end

poll = gears.timer {
    timeout = 1,
    callback = function()
        if not card.popup.visible then return end
        awful.spawn.easy_async({ "playerctl", "-p", PLAYER, "position" }, function(out)
            state.pos = tonumber(out) or 0
            if card.popup.visible then update_card() end
        end)
    end,
}

local function fetch_art(url)
    local function set(p) state.art = p; update_all() end
    if not url or url == "" then return set(nil) end
    if url:match("^file://") then return set((url:gsub("^file://", ""))) end
    local name = url:match("([%w]+)$")
    if not name then return set(nil) end
    local path = ART_DIR .. name .. ".jpg"
    if gears.filesystem.file_readable(path) then return set(path) end
    awful.spawn.easy_async({ "curl", "-sfL", "--max-time", "10", "--create-dirs", "-o", path, url }, function(_, _, _, code)
        if code == 0 then set(path) end
    end)
end

local function set_status(st)
    state.status = (st == "Playing" or st == "Paused") and st or "Stopped"
    if state.status == "Playing" and not on_battery then cava_start() else cava_stop() end
    if state.status == "Playing" then poll:again() else poll:stop() end
    poll:emit_signal("timeout")
    update_all()
end

local function on_metadata(line)
    local artist, title, album, art, length = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)$")
    if not title then state.title = ""; set_status("Stopped"); return end
    state.artist, state.title, state.album = artist, title, album
    state.length = (tonumber(length) or 0) / 1e6
    fetch_art(art)
    poll:emit_signal("timeout")
end

local function destroy(s)
    local b = M.boxes[s]
    if b then b.box.visible = false; M.boxes[s] = nil end
end

local function build(s)
    destroy(s)
    local g    = s.geometry
    local size = math.floor(g.height * ORB_R * 2)
    local b = {}
    b.orb = make_orb(s, size)
    b.box = wibox {
        screen = s, type = "desktop", visible = false,
        ontop = false, below = true, input_passthrough = true,
        bg = "#00000000",
        x = g.x + math.floor(g.width * ORB_X - size / 2),
        y = g.y + math.floor(g.height * ORB_Y - size / 2),
        width = size, height = size,
        widget = b.orb,
    }
    b.s = s
    M.boxes[s] = b
    cover_dirty = true
end

M.status_refresh = function() set_status(state.status) end

M.feed   = function(line) on_metadata(line) end
M.status = function(st) set_status(st) end
M.levels = levels
M.step   = step

function M.init()
    awful.screen.connect_for_each_screen(build)
    screen.connect_signal("removed", destroy)
    screen.connect_signal("property::geometry", function(s) build(s); update_all() end)

    awful.spawn.easy_async_with_shell(
        "pkill -f '^cava -p .*cava/navi'; pkill -f '^playerctl -p " .. PLAYER .. " -F'; true",
        function()
            awful.spawn.with_line_callback({ "playerctl", "-p", PLAYER, "-F", "metadata", "--format",
                "{{artist}}\t{{title}}\t{{album}}\t{{mpris:artUrl}}\t{{mpris:length}}" },
                { stdout = on_metadata })
            awful.spawn.with_line_callback({ "playerctl", "-p", PLAYER, "-F", "status" },
                { stdout = function(line) set_status(line) end })
        end)
end

return M
