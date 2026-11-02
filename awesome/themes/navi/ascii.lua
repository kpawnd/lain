local lgi   = require("lgi")
local cairo = lgi.cairo
local GP    = lgi.GdkPixbuf

local out  = arg[1] or "ascii.png"
local W, H = tonumber(arg[2]) or 2560, tonumber(arg[3]) or 1600
local DIM  = tonumber(arg[4]) or 1
local SRC  = arg[5] or (os.getenv("HOME") .. "/Pictures/wallpapers/lain-wired-exkqk8.jpg")
local CX, CY, SIZE = tonumber(arg[6]) or 2045, tonumber(arg[7]) or 1010, tonumber(arg[8]) or 500
local FONT = "TerminessNerdFontMono"

local RAMP = " .:-=+*xoX#%@"

local function mix(a, b, f) return a + (b - a) * f end
local stops = {
    { 0.00, { 0x24, 0x14, 0x40 } },
    { 0.25, { 0x6a, 0x3c, 0xc0 } },
    { 0.50, { 0xa8, 0x74, 0xec } },
    { 0.75, { 0xe6, 0xa0, 0xcc } },
    { 1.00, { 0xff, 0xf4, 0xfa } },
}
local function palette(t)
    for i = 2, #stops do
        local a, b = stops[i - 1], stops[i]
        if t <= b[1] then
            local f = (t - a[1]) / (b[1] - a[1])
            return mix(a[2][1], b[2][1], f) / 255, mix(a[2][2], b[2][2], f) / 255, mix(a[2][3], b[2][3], f) / 255
        end
    end
    return 1, 1, 1
end

local CH = math.max(7, math.floor(H / (tonumber(os.getenv("NAVI_ROWS")) or 170)))
local surf = cairo.ImageSurface.create(cairo.Format.RGB24, W, H)
local cr   = cairo.Context.create(surf)
cr:set_source_rgb(0, 0, 0); cr:paint()
cr:select_font_face(FONT, cairo.FontSlant.NORMAL, cairo.FontWeight.BOLD)
cr:set_font_size(CH)
local CW = cr:text_extents("M").x_advance

local diam = H * 0.55
local cols = math.floor(diam / CW)
local rows = math.floor(diam / CH)
local pb = GP.Pixbuf.new_from_file(SRC)
pb = pb:new_subpixbuf(math.floor(CX - SIZE / 2), math.floor(CY - SIZE / 2), SIZE, SIZE)
       :scale_simple(cols, rows, GP.InterpType.HYPER)
local px, stride, nch = pb:get_pixels(), pb:get_rowstride(), pb:get_n_channels()
local byte = type(px) == "string" and function(i) return px:byte(i + 1) end or function(i) return px[i + 1] end

local L, inside, list = {}, {}, {}
for y = 0, rows - 1 do
    for x = 0, cols - 1 do
        local i = y * stride + x * nch
        local l = (0.299 * byte(i) + 0.587 * byte(i + 1) + 0.114 * byte(i + 2)) / 255
        local dx, dy = (x + 0.5) / cols - 0.5, (y + 0.5) / rows - 0.5
        local d = math.sqrt(dx * dx + dy * dy) * 2
        L[y * cols + x], inside[y * cols + x] = l, d
        if d <= 1 then list[#list + 1] = l end
    end
end

local SHARP = tonumber(os.getenv("NAVI_SHARP")) or 1.4
local S = {}
for y = 0, rows - 1 do
    for x = 0, cols - 1 do
        local sum, n = 0, 0
        for dy = -1, 1 do for dx = -1, 1 do
            local xx, yy = x + dx, y + dy
            if xx >= 0 and yy >= 0 and xx < cols and yy < rows then sum = sum + L[yy * cols + xx]; n = n + 1 end
        end end
        local v = L[y * cols + x]
        S[y * cols + x] = math.max(0, math.min(1, v + SHARP * (v - sum / n)))
    end
end
L = S
list = {}
for i = 0, rows * cols - 1 do if inside[i] <= 1 then list[#list + 1] = L[i] end end
table.sort(list)
local lo, hi = list[math.floor(#list * 0.03) + 1], list[math.floor(#list * 0.97)]

local PX = tonumber(os.getenv("NAVI_X")) or 0.5
local x0 = math.floor(W * PX - cols * CW / 2)
local y0 = math.floor((H - rows * CH) / 2)
for y = 0, rows - 1 do
    for x = 0, cols - 1 do
        local d = inside[y * cols + x]
        if d <= 1 then
            local t = math.max(0, math.min(1, (L[y * cols + x] - lo) / (hi - lo))) ^ 0.75

            local edge = d > 0.86 and (1 - (d - 0.86) / 0.14) or 1
            local ci = math.floor(t * edge * (#RAMP - 1)) + 1
            local ch = RAMP:sub(ci, ci)
            if ch == " " then ch = (x + y) % 2 == 0 and "." or " " end
            if ch ~= " " then
                local r, g, b = palette(math.max(t * edge, 0.12))
                cr:set_source_rgb(r * DIM, g * DIM, b * DIM)
                cr:move_to(x0 + x * CW, y0 + (y + 1) * CH - CH * 0.2)
                cr:show_text(ch)
            end
        end
    end
end

local function centered(text, y, size, r, g, b, bold)
    cr:select_font_face(FONT, cairo.FontSlant.NORMAL, bold and cairo.FontWeight.BOLD or cairo.FontWeight.NORMAL)
    cr:set_font_size(size)
    cr:set_source_rgb(r * DIM, g * DIM, b * DIM)
    local e = cr:text_extents(text)
    cr:move_to(W * PX - e.x_advance / 2, y)
    cr:show_text(text)
end
local ts = math.floor(H * 0.022)
local words = { "Let's", "all", "love", "Lain" }
for i, wd in ipairs(words) do
    centered(wd, y0 - ts * 1.25 * (#words - i) - ts * 0.9, ts, 0.82, 0.50, 0.65, true)
end

local cross = { "::", "::", "::::::::", "::", "::", "::", "::" }
for i, l in ipairs(cross) do
    centered(l, y0 + rows * CH + ts * 1.6 + (i - 1) * CH * 1.1, CH * 1.1, 0.42, 0.37, 0.50)
end

surf:write_to_png(out)
print(string.format("wrote %s  (%dx%d portrait)", out, cols, rows))
