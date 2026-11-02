local lgi = require("lgi")
local cairo, GdkPixbuf = lgi.cairo, lgi.GdkPixbuf
local Gdk = lgi.require("Gdk", "3.0")
local src, out = arg[1], arg[2]
local W, H = tonumber(arg[3]) or 2560, tonumber(arg[4]) or 1600

local pb = assert(GdkPixbuf.Pixbuf.new_from_file(src))

local s = math.max(W / pb.width, H / pb.height)
local cw, ch = math.floor(pb.width * s + 0.5), math.floor(pb.height * s + 0.5)
pb = pb:scale_simple(cw, ch, "HYPER")
pb = pb:new_subpixbuf(math.floor((cw - W) / 2), math.floor((ch - H) / 2), W, H)

local small = pb:scale_simple(W // 16, H // 16, "HYPER")
local cur = cairo.ImageSurface.create("RGB24", small.width, small.height)
do local c0 = cairo.Context.create(cur); Gdk.cairo_set_source_pixbuf(c0, small, 0, 0); c0:paint() end
local cw, chh = small.width, small.height
while cw < W do
    local nw, nh = math.min(W, cw * 2), math.min(H, chh * 2)
    local nxt = cairo.ImageSurface.create("RGB24", nw, nh)
    local c1 = cairo.Context.create(nxt)
    c1:scale(nw / cw, nh / chh)
    c1:set_source_surface(cur, 0, 0)
    c1:get_source():set_filter("BILINEAR")
    c1:get_source():set_extend("PAD")
    c1:paint()
    cur, cw, chh = nxt, nw, nh
end
local blurred = cur
local surf = cairo.ImageSurface.create("RGB24", W, H)
local cr = cairo.Context.create(surf)
cr:set_source_surface(blurred, 0, 0)
cr:paint()

local g = cairo.LinearPattern.create(0, 0, W, 0)
g:add_color_stop_rgba(0.00, 0.004, 0.020, 0.035, 0.90)
g:add_color_stop_rgba(0.40, 0.006, 0.030, 0.050, 0.78)
g:add_color_stop_rgba(1.00, 0.010, 0.045, 0.075, 0.42)
cr:set_source(g)
cr:paint()

local v = cairo.LinearPattern.create(0, 0, 0, H)
v:add_color_stop_rgba(0.00, 0, 0, 0, 0.45)
v:add_color_stop_rgba(0.25, 0, 0, 0, 0)
v:add_color_stop_rgba(0.75, 0, 0, 0, 0)
v:add_color_stop_rgba(1.00, 0, 0, 0, 0.55)
cr:set_source(v)
cr:paint()

math.randomseed(7)
local T = 256
local tile = cairo.ImageSurface.create("ARGB32", T, T)
do
    local tc = cairo.Context.create(tile)
    for y = 0, T - 1 do for x = 0, T - 1 do
        local v = math.random()
        tc:set_source_rgba(v, v, v, 0.045)
        tc:rectangle(x, y, 1, 1); tc:fill()
    end end
end
local pat = cairo.SurfacePattern.create(tile)
pat:set_extend("REPEAT")
cr:set_source(pat)
cr:paint()
surf:write_to_png(out)
