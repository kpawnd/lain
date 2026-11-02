local xresources = require("beautiful.xresources")
local dpi        = xresources.apply_dpi

local theme = {}

theme.c = {
    black   = "#000000",
    deep    = "#031c2b",
    line    = "#0d314f",
    dim     = "#5b7596",
    fg      = "#d4d5dd",
    accent  = "#5c9ac4",
    accent2 = "#a4b4cb",
    red     = "#c94f5d",
}
local c = theme.c

theme.font      = "JetBrainsMono Nerd Font 10"
theme.wallpaper = os.getenv("HOME") .. "/Pictures/wallpapers/wallhaven-6d17mw/wallhaven-6d17mw.jpg"

theme.bg_normal   = c.black
theme.bg_focus    = c.accent
theme.bg_urgent   = c.red
theme.bg_minimize = c.black
theme.bg_systray  = c.black
theme.fg_normal   = c.fg
theme.fg_focus    = c.black
theme.fg_urgent   = c.black
theme.fg_minimize = c.dim

theme.useless_gap       = dpi(5)
theme.gap_single_client = true
theme.border_width      = dpi(2)
theme.border_normal     = c.line
theme.border_focus      = c.accent
theme.border_marked     = c.accent2

theme.titlebar_bg_normal = c.black
theme.titlebar_fg_normal = c.dim
theme.titlebar_bg_focus  = c.accent
theme.titlebar_fg_focus  = c.black

theme.taglist_bg_focus    = c.black
theme.taglist_fg_focus    = c.fg
theme.taglist_fg_occupied = c.dim
theme.taglist_fg_empty    = c.dim
theme.taglist_bg_urgent   = c.black
theme.taglist_fg_urgent   = c.red

theme.wibar_bg = c.black
theme.wibar_fg = c.fg

theme.menu_height       = dpi(20)
theme.menu_width        = dpi(140)
theme.menu_bg_normal    = c.black
theme.menu_fg_normal    = c.fg
theme.menu_bg_focus     = c.accent
theme.menu_fg_focus     = c.black
theme.menu_border_color = c.accent
theme.menu_border_width = dpi(2)

theme.notification_bg           = c.black
theme.notification_fg           = c.fg
theme.notification_border_color = c.accent
theme.notification_border_width = dpi(2)
theme.notification_margin       = dpi(10)
theme.notification_font         = theme.font
theme.notification_icon_size    = dpi(40)
theme.icon_theme                = "Adwaita"

theme.prompt_bg = c.black
theme.prompt_fg = c.accent

return theme
