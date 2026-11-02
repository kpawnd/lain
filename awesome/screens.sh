#!/usr/bin/env bash

Q=$(xrandr --query) || exit 1

INT=$(awk '$2=="connected" && $1 ~ /^eDP/ {print $1; exit}' <<<"$Q")
[ -n "$INT" ] || INT=eDP-1
RATE_INT=240; [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = 0 ] && RATE_INT=60
args=(--output "$INT" --primary --mode 2560x1600 --rate "$RATE_INT" --pos 0x0)

EXT=$(awk -v i="$INT" '$2=="connected" && $1!=i {print $1; exit}' <<<"$Q")
if [ -n "$EXT" ]; then
    read -r MODE RATE < <(awk -v o="$EXT" '
        $1==o {f=1; next}
        f && /^ / {m=0; for(i=2;i<=NF;i++){r=$i; gsub(/[*+]/,"",r); if(r+0>m)m=r+0}; print $1, m; exit}
        f {exit}' <<<"$Q")
    if [ -n "$MODE" ]; then
        args+=(--output "$EXT" --mode "$MODE" --rate "$RATE" --scale 1x1 --right-of "$INT")
    else
        args+=(--output "$EXT" --auto --right-of "$INT")
    fi
fi

while read -r o; do args+=(--output "$o" --off); done < <(awk '$2=="disconnected"{print $1}' <<<"$Q")

xrandr "${args[@]}"
