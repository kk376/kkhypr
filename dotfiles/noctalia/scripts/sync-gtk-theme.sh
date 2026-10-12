#!/usr/bin/env bash
# Sync GTK3, GTK4, Libadwaita, and Chromium browser themes with active Noctalia palette
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
GTK4_CSS="$CONFIG_DIR/gtk-4.0/noctalia.css"

# 1. Calculate nearest GNOME accent color from active Noctalia accent
if [ -f "$GTK4_CSS" ]; then
    nearest_accent=$(python3 - <<'PY' 2>/dev/null || true
import os, re, colorsys

css_path = os.path.expanduser("~/.config/gtk-4.0/noctalia.css")
if not os.path.isfile(css_path):
    raise SystemExit(1)

content = open(css_path).read()
m = re.search(r'@define-color\s+accent_color\s+#([0-9a-fA-F]{6});', content)
if not m:
    raise SystemExit(1)

hex_str = m.group(1)
r, g, b = (int(hex_str[i:i+2], 16)/255.0 for i in (0, 2, 4))
h, l, s = colorsys.rgb_to_hls(r, g, b)

gnome_accents = {
    'blue': 0.60,
    'teal': 0.50,
    'green': 0.33,
    'yellow': 0.14,
    'orange': 0.08,
    'red': 0.00,
    'pink': 0.92,
    'purple': 0.78,
}

if s < 0.2:
    print('slate')
else:
    best = min(gnome_accents.items(), key=lambda item: min(abs(h - item[1]), 1.0 - abs(h - item[1])))[0]
    print(best)
PY
)
    if [ -n "$nearest_accent" ]; then
        current_accent=$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'" || true)
        if [ "$current_accent" = "$nearest_accent" ]; then
            # Temporarily pulse to sibling accent so GSettings/dconf emits a guaranteed Changed signal
            temp_accent="blue"
            [ "$nearest_accent" = "blue" ] && temp_accent="teal"
            gsettings set org.gnome.desktop.interface accent-color "$temp_accent" 2>/dev/null || true
            sleep 0.05
        fi
        gsettings set org.gnome.desktop.interface accent-color "$nearest_accent" 2>/dev/null || true
    fi
fi

# 2. Pulse GTK theme with guaranteed debounce gap to broadcast DBus signal to Chrome, Brave, and GTK apps
sleep 0.05
current_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || true)
if [ "$current_theme" = "adw-gtk3-dark" ]; then
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3" 2>/dev/null || true
    sleep 0.05
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
else
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
    if [ -n "$current_theme" ]; then
        sleep 0.05
        gsettings set org.gnome.desktop.interface gtk-theme "$current_theme" 2>/dev/null || true
    fi
fi

# 3. Clean up headless background daemons with no visible windows so their next launch uses fresh state
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    open_classes=$(hyprctl clients -j 2>/dev/null | jq -r '.[].class' 2>/dev/null || true)
    if ! echo "$open_classes" | grep -qi "clocks"; then
        pkill -f "gnome-clocks" 2>/dev/null || true
    fi
    if ! echo "$open_classes" | grep -qi "calculator"; then
        pkill -f "gnome-calculator" 2>/dev/null || true
    fi
fi

# 4. Synchronize btop theme and notify running instances
if [ -f "$GTK4_CSS" ]; then
    python3 - <<'PY' 2>/dev/null || true
import os, re

config_dir = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config"))
gtk4_css = os.path.join(config_dir, "gtk-4.0", "noctalia.css")
ghostty_theme = os.path.join(config_dir, "ghostty", "themes", "noctalia")
btop_theme_dir = os.path.join(config_dir, "btop", "themes")
btop_theme_file = os.path.join(btop_theme_dir, "noctalia.theme")

if not os.path.isfile(gtk4_css):
    raise SystemExit(0)

with open(gtk4_css, "r", encoding="utf-8") as f:
    css = f.read()

def get_css_color(name, default="#888888"):
    m = re.search(rf'@define-color\s+{name}\s+#([0-9a-fA-F]{{6}});', css)
    return f"#{m.group(1)}" if m else default

accent = get_css_color("accent_color", "#52d7f0")
bg = get_css_color("window_bg_color", "#0f131c")
fg = get_css_color("window_fg_color", "#dfe2ef")
card_bg = get_css_color("card_bg_color", "#1b2029")

palette = {}
if os.path.isfile(ghostty_theme):
    with open(ghostty_theme, "r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r'palette\s*=\s*(\d+)=#?([0-9a-fA-F]{6})', line)
            if m:
                palette[int(m.group(1))] = f"#{m.group(2)}"

p2 = palette.get(2, accent)
p3 = palette.get(3, accent)
p4 = palette.get(4, accent)
p8 = palette.get(8, "#8891a5")
p0 = palette.get(0, "#3e4759")

btop_content = f"""# btop theme synchronized with active Noctalia palette

theme[main_bg]="{bg}"
theme[main_fg]="{fg}"
theme[title]="{accent}"
theme[hi_fg]="{p4}"
theme[selected_bg]="{card_bg}"
theme[selected_fg]="{fg}"
theme[inactive_fg]="{p8}"
theme[proc_misc]="{p3}"
theme[cpu_box]="{p8}"
theme[mem_box]="{p8}"
theme[net_box]="{p8}"
theme[proc_box]="{p8}"
theme[div_line]="{p0}"
theme[temp_start]="{accent}"
theme[temp_mid]="{p3}"
theme[temp_end]="{p4}"
theme[cpu_start]="{accent}"
theme[cpu_mid]="{p3}"
theme[cpu_end]="{p4}"
theme[free_start]="{accent}"
theme[free_mid]="{p3}"
theme[free_end]="{p4}"
theme[cached_start]="{accent}"
theme[cached_mid]="{p3}"
theme[cached_end]="{p4}"
theme[available_start]="{accent}"
theme[available_mid]="{p3}"
theme[available_end]="{p4}"
theme[used_start]="{accent}"
theme[used_mid]="{p3}"
theme[used_end]="{p4}"
theme[download_start]="{accent}"
theme[download_mid]="{p3}"
theme[download_end]="{p4}"
theme[upload_start]="{accent}"
theme[upload_mid]="{p3}"
theme[upload_end]="{p4}"
"""

os.makedirs(btop_theme_dir, exist_ok=True)
with open(btop_theme_file, "w", encoding="utf-8") as f:
    f.write(btop_content)
PY
    if pgrep -x btop >/dev/null 2>&1; then
        pkill -SIGUSR2 -x btop || true
    fi
fi

# 5. Broadcast SIGUSR1 to active Neovim instances for live palette and transparency refresh
pkill -SIGUSR1 -x nvim 2>/dev/null || pkill -SIGUSR1 nvim 2>/dev/null || true

# 6. Synchronize Foot terminal and tmux live color palette via OSC sequences and theme reload
python3 - <<'PY' 2>/dev/null || true
import os, re, subprocess

config_dir = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config"))
foot_theme = os.path.join(config_dir, "foot", "themes", "noctalia")
tmux_theme_dir = os.path.join(config_dir, "tmux", "themes")
tmux_theme = os.path.join(tmux_theme_dir, "noctalia.conf")

if os.path.isfile(foot_theme):
    foot_colors = {}
    with open(foot_theme, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("["):
                k, v = line.split("=", 1)
                foot_colors[k.strip()] = v.strip()

    bg = foot_colors.get("background", "1e100d")
    fg = foot_colors.get("foreground", "f9dcd7")
    primary = foot_colors.get("regular4", "ffaceb")
    outline = foot_colors.get("bright0", "ae8881")
    outline_var = foot_colors.get("regular0", "5d3f3a")
    card_bg = foot_colors.get("regular0", "2b1c19")

    tmux_content = f"""# Generated by Noctalia synchronization hook
set -gq @noctalia_surface "#{bg}"
set -gq @noctalia_on_surface "#{fg}"
set -gq @noctalia_surface_container_low "#{card_bg}"
set -gq @noctalia_surface_container "#{card_bg}"
set -gq @noctalia_surface_container_highest "#{outline_var}"
set -gq @noctalia_on_surface_variant "#{outline}"
set -gq @noctalia_outline "#{outline}"
set -gq @noctalia_outline_variant "#{outline_var}"
set -gq @noctalia_primary "#{primary}"
set -gq @noctalia_on_primary "#{bg}"
set -gq @noctalia_primary_container "#{primary}"
set -gq @noctalia_on_primary_container "#{fg}"

set -gqF status-style "bg=#{{@noctalia_surface_container_low}},fg=#{{@noctalia_on_surface}}"
set -gqF window-status-style "bg=#{{@noctalia_surface_container}},fg=#{{@noctalia_on_surface_variant}}"
set -gqF window-status-current-style "bg=#{{@noctalia_surface_container_highest}},fg=#{{@noctalia_on_surface}},bold"
set -gqF pane-border-style "fg=#{{@noctalia_outline_variant}}"
set -gqF pane-active-border-style "fg=#{{@noctalia_primary}}"
"""
    os.makedirs(tmux_theme_dir, exist_ok=True)
    with open(tmux_theme, "w", encoding="utf-8") as f:
        f.write(tmux_content)

    if subprocess.call(["pgrep", "-x", "tmux"], stdout=subprocess.DEVNULL) == 0:
        subprocess.call(["tmux", "source-file", tmux_theme], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Broadcast OSC escape sequences to all active Foot pseudo-terminals
    seq = ""
    for i in range(8):
        if f"regular{i}" in foot_colors:
            seq += f"\033]4;{i};#{foot_colors[f'regular{i}']}\033\\"
    for i in range(8):
        if f"bright{i}" in foot_colors:
            seq += f"\033]4;{i+8};#{foot_colors[f'bright{i}']}\033\\"
    if "foreground" in foot_colors:
        seq += f"\033]10;#{foot_colors['foreground']}\033\\"
    if "background" in foot_colors:
        seq += f"\033]11;#{foot_colors['background']}\033\\"
    if "cursor" in foot_colors:
        parts = foot_colors["cursor"].split()
        if len(parts) > 1:
            seq += f"\033]12;#{parts[1]}\033\\"

    if seq:
        ttys = set()
        try:
            foot_pids = subprocess.check_output(["pgrep", "-x", "foot"]).decode().split()
            for fpid in foot_pids:
                try:
                    children = subprocess.check_output(["pgrep", "-P", fpid]).decode().split()
                    for cpid in children:
                        fd0 = os.path.realpath(f"/proc/{cpid}/fd/0")
                        if fd0.startswith("/dev/pts/"):
                            ttys.add(fd0)
                except Exception: pass
        except Exception: pass
        try:
            clients = subprocess.check_output(["tmux", "list-clients", "-F", "#{client_tty}"]).decode().split()
            for c in clients:
                if c.startswith("/dev/pts/"):
                    ttys.add(c)
        except Exception: pass

        data = seq.encode("latin1")
        for tty_path in ttys:
            try:
                with open(tty_path, "wb", buffering=0) as tty:
                    tty.write(data)
            except Exception: pass
PY


