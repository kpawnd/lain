# lain

A Serial Experiments Lain themed config for [awesome](https://awesomewm.org) 4.3. Black and wired blue, text only.

![desktop](screenshots/desktop.png)
![work](screenshots/work.png)

## Features

- Text-only top and bottom bars: audio, memory, CPU (with RAPL watts), battery, GPU, ROG mode and fans, Wi-Fi, now playing
- Visualiser orb on the wallpaper, driven by cava, with the navi logo in the middle
- Now-playing card (click `playing:` in the bottom bar)
- Volume and brightness OSD, drop-down terminal, key help popup
- Per-monitor DPI, plus automatic laptop/external monitor setup with `screens.sh`

## What's here

| Folder | Goes to | What |
| --- | --- | --- |
| `awesome/` | `~/.config/awesome` | window manager, bars, visualiser |
| `alacritty/` | `~/.config/alacritty` | terminal, navi palette |
| `rofi/` | `~/.config/rofi` | app launcher and window picker |
| `picom/` | `~/.config/picom` | compositor: blur, shadows, fades |
| `fastfetch/` | `~/.config/fastfetch` | system info with the navi logo |
| `cava/` | `~/.config/cava` | audio feed for the visualiser |
| `navi-lock/` | `~/.config/navi-lock` | lock screen background generator |
| `bin/` | `~/.local/bin` | `navi-lock`, `rog-menu`, `navifetch` |

## Install

```sh
git clone https://github.com/kpawnd/lain.git
cd lain
mkdir -p ~/.config ~/.local/bin
cp -r awesome alacritty rofi picom fastfetch cava navi-lock ~/.config/
cp bin/* ~/.local/bin/
```

This overwrites any existing configs with the same names, so back yours up first.

Put a wallpaper at `~/.config/awesome/wallpaper.jpg`. Without one the desktop is plain black.
The browser is `$BROWSER`, falling back to `thorium-browser`.

Run `navifetch` for fastfetch with the biggest logo that fits the terminal.
To rebuild the logos after editing `fastfetch/navi.txt`, run `lua5.3 ~/.config/fastfetch/navigen.lua`.

## Dependencies

`alacritty` `rofi` `picom` `fastfetch` `cava` `playerctl` `pactl` `brightnessctl` `maim` `xclip` `yazi` `btop` `pavucontrol` `JetBrainsMono Nerd Font`

Lock screen: `i3lock-color` (falls back to `slock`), `Inter` font, `lua-lgi`

Optional: `asusctl` `udiskie` `xss-lock` `clipmenu`

Some widgets and `rog-menu` are written for an ASUS ROG laptop (battery, fans, dGPU, refresh-rate switching).

## Keys

Press `Super + /` to see all keybindings.

| Key | Action |
| --- | --- |
| `Super + Enter` | terminal |
| `Super + Space` | app launcher |
| `Super + Q` | close window |
| `Super + Tab` | cycle layout |
| `Super + 1..5` | workspace |
| `` Super + ` `` | drop-down terminal |
| `Super + Esc` | power menu |

## License

[MIT](LICENSE)
