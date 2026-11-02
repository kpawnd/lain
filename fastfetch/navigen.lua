local DIR = (arg[0]:match("^(.*)/[^/]*$") or ".") .. "/"
local SIZES   = { 26, 32, 42 }
local BRAILLE = { 52, 60, 72 }

local INK = { ["."] = 0.30, ["'"] = 0.32, [","] = 0.42, [":"] = 0.58, [";"] = 0.72, ["c"] = 1.0 }

local src, W0 = {}, 0
for line in io.lines(DIR .. "navi.txt") do
    local row, col, layer = {}, 0, 2
    local i = 1
    while i <= #line do
        local ch = line:sub(i, i)
        if ch == "$" and line:sub(i + 1, i + 1):match("%d") then
            layer = tonumber(line:sub(i + 1, i + 1)); i = i + 2
        else
            col = col + 1
            local ink = INK[ch] or (ch:match("%a") and 1.0) or 0
            row[col] = { b = layer == 1 and ink or 0, d = layer ~= 1 and ink or 0 }
            i = i + 1
        end
    end
    if col > W0 then W0 = col end
    src[#src + 1] = row
end
local H0 = #src
local function at(x, y)
    local r = src[y + 1]; local c = r and r[x + 1]
    if not c then return 0, 0 end
    return c.b, c.d
end

local function box(x0, x1, y0, y1)
    local sb, sd, area = 0, 0, 0
    for y = math.floor(y0), math.ceil(y1) - 1 do
        local hy = math.min(y + 1, y1) - math.max(y, y0)
        if hy > 0 then
            for x = math.floor(x0), math.ceil(x1) - 1 do
                local wx = math.min(x + 1, x1) - math.max(x, x0)
                if wx > 0 then
                    local b, d = at(x, y)
                    sb, sd, area = sb + b * wx * hy, sd + d * wx * hy, area + wx * hy
                end
            end
        end
    end
    if area == 0 then return 0, 0 end
    return sb / area, sd / area
end

local function bilinear(fx, fy)
    local x0, y0 = math.floor(fx), math.floor(fy)
    local tx, ty = fx - x0, fy - y0
    local b00, d00 = at(x0, y0);     local b10, d10 = at(x0 + 1, y0)
    local b01, d01 = at(x0, y0 + 1); local b11, d11 = at(x0 + 1, y0 + 1)
    local function mix(a, b, c, d) return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty end
    return mix(b00, b10, b01, b11), mix(d00, d10, d01, d11)
end

local DUST   = { { 0.20, "." }, { 0.34, "'" }, { 0.46, "," }, { 0.58, ":" }, { 0.70, ";" } }
local STROKE = { { 0.20, "." }, { 0.34, ":" }, { 0.46, "c" } }
local function pick(ramp, v)
    local ch = nil
    for _, s in ipairs(ramp) do if v >= s[1] then ch = s[2] end end
    return ch
end

local function build(W)
    if W == W0 then
        local out = {}
        for y = 1, H0 do
            local line, cur = {}, nil
            local band = y <= H0 * 0.34 and "$1" or (y <= H0 * 0.67 and "$3" or "$4")
            for x = 1, W0 do
                local c = src[y][x]
                local ch = " "
                local want = cur
                if c and (c.b > 0 or c.d > 0) then
                    local orig = nil
                    for k, v in pairs(INK) do if (c.b > 0 and c.b or c.d) == v then orig = k end end
                    ch = orig or "c"
                    want = c.b > 0 and band or "$2"
                end
                if want ~= cur then line[#line + 1] = want; cur = want end
                line[#line + 1] = ch
            end
            out[#out + 1] = (table.concat(line):gsub("%s+$", ""))
        end
        return out
    end
    local H = math.max(4, math.floor(W * H0 / W0 + 0.5))
    local sx, sy = W0 / W, H0 / H
    local grow = W > W0
    local out = {}
    for y = 0, H - 1 do
        local line, cur = {}, nil
        local band = (y + 0.5) <= H * 0.34 and "$1" or ((y + 0.5) <= H * 0.67 and "$3" or "$4")
        for x = 0, W - 1 do
            local b, d
            if grow then

                local c = src[math.floor((y + 0.5) * sy) + 1]
                c = c and c[math.floor((x + 0.5) * sx) + 1]
                local ch = " "
                if c then for k, v in pairs(INK) do if (c.b > 0 and c.b or c.d) == v then ch = k end end end
                local want = (c and c.b > 0) and band or (ch ~= " " and "$2" or cur)
                if want ~= cur then line[#line + 1] = want; cur = want end
                line[#line + 1] = ch
                goto next
            else
                b, d = box(x * sx, (x + 1) * sx, y * sy, (y + 1) * sy)

                b = math.min(1, b * (1 + 0.6 * (sx - 1)))
            end
            local ch, want
            if b >= d * 0.8 and b > 0 then
                ch = pick(STROKE, b); want = band
            end
            if not ch then ch = pick(DUST, d); want = "$2" end
            if not ch then ch = " "; want = cur end
            if want ~= cur then line[#line + 1] = want; cur = want end
            line[#line + 1] = ch
            ::next::
        end
        out[#out + 1] = (table.concat(line):gsub("%s+$", ""))
    end

    while #out > 0 and not out[1]:gsub("%$%d", ""):match("%S") do table.remove(out, 1) end
    while #out > 0 and not out[#out]:gsub("%$%d", ""):match("%S") do table.remove(out) end
    return out
end

local SIG = 0.42
local function field(fx, fy)
    local sb, sd, sw = 0, 0, 0
    for dy = -2, 2 do for dx = -2, 2 do
        local x, y = math.floor(fx) + dx, math.floor(fy) + dy
        local cx, cy = x + 0.5 - fx, (y + 0.5 - fy) * 2
        local w = math.exp(-(cx * cx + cy * cy) / (2 * SIG * SIG))
        local b, d = at(x, y); sb, sd, sw = sb + b * w, sd + d * w, sw + w
    end end
    return sb / sw, sd / sw
end
local BAYER = { [0] = { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
local DOT = { { 0x01, 0x08 }, { 0x02, 0x10 }, { 0x04, 0x20 }, { 0x40, 0x80 } }
local function build_braille(W)
    local SW = W * 2
    local SH = math.floor(SW * (H0 * 2) / W0 / 4 + 0.5) * 4
    local H = SH // 4
    local out = {}
    for cy = 0, H - 1 do
        local line, cur = {}, nil
        local band = (cy + 0.5) <= H * 0.34 and "$1" or ((cy + 0.5) <= H * 0.67 and "$3" or "$4")
        for cx = 0, W - 1 do
            local mask, nb, nd = 0, 0, 0
            for py = 0, 3 do for px = 0, 1 do
                local gx, gy = cx * 2 + px, cy * 4 + py
                local b, d = field((gx + 0.5) / SW * W0, (gy + 0.5) / SH * H0)
                if b > 0.42 then mask = mask | DOT[py + 1][px + 1]; nb = nb + 1
                elseif d * 0.9 > BAYER[gy % 4][gx % 4 + 1] / 16 + 0.03 then
                    mask = mask | DOT[py + 1][px + 1]; nd = nd + 1
                end
            end end
            local ch = mask == 0 and " " or utf8.char(0x2800 + mask)
            local want = mask == 0 and cur or (nb >= nd and band or "$2")
            if want ~= cur then line[#line + 1] = want; cur = want end
            line[#line + 1] = ch
        end
        out[#out + 1] = (table.concat(line):gsub("%s+$", ""))
    end
    return out
end

if arg[1] then
    local w = tonumber(arg[1])
    print(table.concat(w > W0 and build_braille(w) or build(w), "\n"))
else
    os.execute("mkdir -p '" .. DIR .. "logos'")
    for _, W in ipairs(SIZES) do
        local f = assert(io.open(DIR .. "logos/navi-" .. W .. ".txt", "w"))
        f:write(table.concat(build(W), "\n"), "\n")
        f:close()
    end
    for _, W in ipairs(BRAILLE) do
        local f = assert(io.open(DIR .. "logos/navi-" .. W .. ".txt", "w"))
        f:write(table.concat(build_braille(W), "\n"), "\n")
        f:close()
    end
    print("wrote " .. (#SIZES + #BRAILLE) .. " logos to " .. DIR .. "logos/")
end
