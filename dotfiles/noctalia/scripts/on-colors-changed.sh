#!/usr/bin/env bash
# ==============================================================================
# Noctalia Color Synchronization Hook
# Dispatches active palette updates to GTK, Chromium, KDE 6, and terminals
# ==============================================================================
set -euo pipefail

# Guard against concurrent executions via file lock
exec 200>/tmp/noctalia-colors-changed.lock
flock -w 1 200 || exit 0

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CSS_FILE="$CONFIG_DIR/gtk-3.0/noctalia.css"

if [ ! -f "$CSS_FILE" ]; then
    CSS_FILE="$CONFIG_DIR/gtk-4.0/noctalia.css"
fi

if [ -f "$CSS_FILE" ]; then
    nearest_accent=$(python3 - <<'PY' 2>/dev/null || true
import os, re, colorsys

css_path = os.path.expanduser(os.environ.get("CSS_FILE", "~/.config/gtk-3.0/noctalia.css"))
if not os.path.isfile(css_path):
    raise SystemExit(1)

content = open(css_path).read()
m = re.search(r'@define-color\s+accent_color\s+#([0-9a-fA-F]{6});', content)
if not m:
    raise SystemExit(1)

hex_str = m.group(1)
r, g, b = (int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4))
h, l, s = colorsys.rgb_to_hls(r, g, b)

gnome_accents = {
    'red': 0.00,
    'orange': 0.08,
    'yellow': 0.14,
    'green': 0.33,
    'teal': 0.50,
    'blue': 0.60,
    'purple': 0.78,
    'pink': 0.92,
}

if s < 0.2:
    print('slate')
else:
    best = min(gnome_accents.items(), key=lambda item: min(abs(h - item[1]), 1.0 - abs(h - item[1])))[0]
    print(best)
PY
)
    if [ -n "$nearest_accent" ] && command -v gsettings >/dev/null 2>&1; then
        current_accent=$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'" || true)
        if [ "$current_accent" = "$nearest_accent" ]; then
            temp_accent="blue"
            [ "$nearest_accent" = "blue" ] && temp_accent="teal"
            gsettings set org.gnome.desktop.interface accent-color "$temp_accent" 2>/dev/null || true
            sleep 0.05
        fi
        gsettings set org.gnome.desktop.interface accent-color "$nearest_accent" 2>/dev/null || true
    fi
fi

# Pulse GTK theme to broadcast style invalidation to running GTK and Chromium windows
if command -v gsettings >/dev/null 2>&1; then
    current_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || true)
    [ -z "$current_theme" ] && current_theme="adw-gtk3-dark"

    temp_theme="adw-gtk3"
    [ "$current_theme" = "adw-gtk3" ] && temp_theme="adw-gtk3-dark"

    gsettings set org.gnome.desktop.interface gtk-theme "$temp_theme" 2>/dev/null || true
    sleep 0.1
    gsettings set org.gnome.desktop.interface gtk-theme "$current_theme" 2>/dev/null || true
fi

# Ensure case-insensitive color-scheme compatibility symlink
if [ -f "$HOME/.local/share/color-schemes/noctalia.colors" ] && [ ! -L "$HOME/.local/share/color-schemes/Noctalia.colors" ]; then
    ln -sf noctalia.colors "$HOME/.local/share/color-schemes/Noctalia.colors" 2>/dev/null || true
fi

# Broadcast palette update to running KDE 6 applications (Dolphin)
python3 - <<'PY' 2>/dev/null || true
import dbus

try:
    bus = dbus.SessionBus()
    bus.request_name('org.kde.kconfig.notify')
    payload = dbus.Dictionary({
        dbus.String('General'): dbus.Array([dbus.ByteArray(b'ColorScheme')], signature='ay')
    }, signature='saay')
    msg1 = dbus.lowlevel.SignalMessage('/kdeglobals', 'org.kde.kconfig.notify', 'ConfigChanged')
    msg1.append(payload, signature='a{saay}')
    bus.send_message(msg1)
    bus.release_name('org.kde.kconfig.notify')

    bus.request_name('org.kde.KGlobalSettings')
    msg2 = dbus.lowlevel.SignalMessage('/KGlobalSettings', 'org.kde.KGlobalSettings', 'notifyChange')
    msg2.append(dbus.Int32(0), signature='i')
    msg2.append(dbus.Int32(0), signature='i')
    bus.send_message(msg2)
    bus.release_name('org.kde.KGlobalSettings')
except Exception:
    pass
PY

if command -v busctl >/dev/null 2>&1; then
    for name in $(busctl --user list --acquired 2>/dev/null | awk '{print $1}' | grep -E '^org\.kde\.dolphin'); do
        busctl --user call "$name" /dolphin/Dolphin_1/actions/view_redisplay org.qtproject.Qt.QAction trigger 2>/dev/null || true
    done
fi

# Notify active terminal monitors and editors
if command -v pgrep >/dev/null 2>&1; then
    if pgrep -x btop >/dev/null 2>&1; then
        pkill -SIGUSR2 -x btop 2>/dev/null || true
    fi
    pkill -SIGUSR1 -x nvim 2>/dev/null || true
fi

# Reload Hyprland to update border colors and dismiss any recovery overlay
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload 2>/dev/null || true
fi
