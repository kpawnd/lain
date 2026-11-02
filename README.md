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

## Install

```sh
git clone https://github.com/kpawnd/lain.git
cp -r lain/awesome ~/.config/awesome
cp lain/cava/navi ~/.config/cava/navi
cp lain/fastfetch/navi.txt ~/.config/fastfetch/navi.txt
```

Set the wallpaper path in `awesome/themes/navi/theme.lua`.

## Dependencies

`alacritty` `rofi` `picom` `cava` `playerctl` `pactl` `brightnessctl` `maim` `xclip` `yazi` `btop` `pavucontrol` `JetBrainsMono Nerd Font`

Optional: `asusctl` `udiskie` `xss-lock` `clipmenu`

Some widgets are written for an ASUS ROG laptop (battery, fans, dGPU, refresh-rate switching).

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
