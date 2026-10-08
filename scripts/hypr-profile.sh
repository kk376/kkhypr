#!/usr/bin/env bash
# ==============================================================================
# hypr-profile.sh: Switch Hyprland appearance between default (solid) and blur
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve active repository root
if [[ -d "$SCRIPT_DIR/../presets" ]]; then
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -L "$HOME/.config/hypr/hyprland.lua" ]]; then
    target="$(readlink -f "$HOME/.config/hypr/hyprland.lua")"
    REPO_DIR="$(dirname "$(dirname "$(dirname "$target")")")"
elif [[ -d "$HOME/code/kkhypr/presets" ]]; then
    REPO_DIR="$HOME/code/kkhypr"
elif [[ -d "$HOME/code/dev-suite/hyprland-dots/presets" ]]; then
    REPO_DIR="$HOME/code/dev-suite/hyprland-dots"
else
    REPO_DIR="$SCRIPT_DIR/.."
fi

MODE="${1:-}"

if [[ "$MODE" != "default" && "$MODE" != "blur" ]]; then
    printf "Usage: hypr-profile.sh {default|blur}\n"
    printf "  default: 100%% solid, fully opaque surfaces without compositor blur\n"
    printf "  blur:    glassmorphism with compositor blur and translucency\n"
    exit 1
fi

PRESET_DIR="$REPO_DIR/presets/$MODE"
DOTFILES_DIR="$REPO_DIR/dotfiles"

if [[ ! -d "$PRESET_DIR" ]]; then
    printf "[ERROR] Preset directory not found: %s\n" "$PRESET_DIR" >&2
    exit 1
fi

# Copy preset configuration files into active dotfiles tree
cp -f "$PRESET_DIR/btop/btop.conf" "$DOTFILES_DIR/btop/btop.conf"
cp -f "$PRESET_DIR/ghostty/config.ghostty" "$DOTFILES_DIR/ghostty/config.ghostty"
cp -f "$PRESET_DIR/ghostty/gtk.css" "$DOTFILES_DIR/ghostty/gtk.css"
cp -f "$PRESET_DIR/hypr/hyprland.lua" "$DOTFILES_DIR/hypr/hyprland.lua"
cp -f "$PRESET_DIR/noctalia/config.toml" "$DOTFILES_DIR/noctalia/config.toml"

# Update Noctalia state overrides if present
STATE_SETTINGS="$HOME/.local/state/noctalia/settings.toml"
if [[ -f "$STATE_SETTINGS" ]]; then
    if [[ "$MODE" == "default" ]]; then
        sed -i 's/settings_window_translucent = true/settings_window_translucent = false/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "glass"/transparency_mode = "solid"/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "soft"/transparency_mode = "solid"/g' "$STATE_SETTINGS"
        sed -i 's/background_opacity = 0.88/background_opacity = 1.0/g' "$STATE_SETTINGS"
    else
        sed -i 's/settings_window_translucent = false/settings_window_translucent = true/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "solid"/transparency_mode = "glass"/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "soft"/transparency_mode = "glass"/g' "$STATE_SETTINGS"
        sed -i 's/background_opacity = 1.0/background_opacity = 0.88/g' "$STATE_SETTINGS"
    fi
fi

# Reload Hyprland compositor
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# Restart Noctalia shell
if pgrep -x noctalia >/dev/null 2>&1; then
    pkill -x noctalia 2>/dev/null || true
    sleep 0.4
    nohup noctalia -d >/dev/null 2>&1 &
fi

# Reload Ghostty terminal configuration
gdbus call --session --dest com.mitchellh.ghostty --object-path /com/mitchellh/ghostty --method org.gtk.Actions.Activate reload-config "[]" "{}" >/dev/null 2>&1 || pkill -SIGUSR2 ghostty 2>/dev/null || true

if [[ "$MODE" == "default" ]]; then
    printf "[PASS] Hyprland profile switched to: default (solid opaque, blur disabled)\n"
else
    printf "[PASS] Hyprland profile switched to: blur (glassmorphism, blur enabled)\n"
fi
