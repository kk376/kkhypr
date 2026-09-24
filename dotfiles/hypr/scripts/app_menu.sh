#!/bin/bash
# Active Application Context Menu
# Displays a popup menu to quit or manage the currently active window.

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

pkill -x wofi 2>/dev/null || true

# Get active window class or title for prompt label
title=$(hyprctl activewindow -j 2>/dev/null | grep -oP '"class":\s*"\K[^"]+' || echo "App")

# Render concise popup menu anchored below the active window icon on the top bar
choice=$(printf "quit\n" | wofi --dmenu \
    --lines 1 \
    --hide-search \
    --width 130 \
    --location top_left \
    --xoffset 155 \
    --yoffset 36 \
    --prompt "${title}" 2>/dev/null)

if [ "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" = "quit" ]; then
    hyprctl dispatch killactive
fi
