#!/usr/bin/env bash
# ==============================================================================
# hypr-profile.sh: Switch Hyprland appearance between default (solid) and blur
# Supports custom opacity: hypr-profile.sh blur [0.x] or hypr-blur [0.x]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Resolve active repository root
if [[ -d "$SCRIPT_DIR/../presets" ]]; then
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "$HOME/code/kkhypr/presets" ]]; then
    REPO_DIR="$HOME/code/kkhypr"
elif [[ -d "$HOME/code/dev-suite/hyprland-dots/presets" ]]; then
    REPO_DIR="$HOME/code/dev-suite/hyprland-dots"
else
    REPO_DIR="$SCRIPT_DIR/.."
fi

MODE=""
TARGET_OPACITY=""
RESTART_NOCTALIA=false

# Parse arguments flexibly: e.g. "blur", "blur 0.85", "0.95", "default", "--restart", "-r"
for arg in "$@"; do
    if [[ "$arg" == "default" ]]; then
        MODE="default"
    elif [[ "$arg" == "blur" ]]; then
        MODE="blur"
    elif [[ "$arg" == "--restart" || "$arg" == "-r" ]]; then
        RESTART_NOCTALIA=true
    elif [[ "$arg" =~ ^(0(\.[0-9]+)?|1(\.0+)?|\.[0-9]+)$ ]]; then
        TARGET_OPACITY="$arg"
        if [[ "$TARGET_OPACITY" =~ ^\.[0-9]+$ ]]; then
            TARGET_OPACITY="0${TARGET_OPACITY}"
        fi
    fi
done

# If no explicit mode given, but an opacity number was supplied, default mode to blur
if [[ -z "$MODE" ]]; then
    if [[ -n "$TARGET_OPACITY" ]]; then
        MODE="blur"
    else
        printf "Usage: hypr-profile.sh {default|blur} [opacity: 0.x] [--restart]\n"
        printf "  default: 100%% solid, fully opaque surfaces without compositor blur\n"
        printf "  blur:    glassmorphism with compositor blur (default opacity 0.95, or custom 0.x)\n"
        exit 1
    fi
fi

if [[ "$MODE" == "blur" ]]; then
    OPACITY="${TARGET_OPACITY:-0.95}"
else
    OPACITY="1.0"
fi

PRESET_DIR="$REPO_DIR/presets/$MODE"
DOTFILES_DIR="$REPO_DIR/dotfiles"

if [[ ! -d "$PRESET_DIR" ]]; then
    printf "[ERROR] Preset directory not found: %s\n" "$PRESET_DIR" >&2
    exit 1
fi

# Copy preset configuration files into active dotfiles tree and config tree
if [[ -d "$DOTFILES_DIR" ]]; then
    cp -f "$PRESET_DIR/btop/btop.conf" "$DOTFILES_DIR/btop/btop.conf"
    cp -f "$PRESET_DIR/ghostty/config.ghostty" "$DOTFILES_DIR/ghostty/config.ghostty"
    cp -f "$PRESET_DIR/ghostty/gtk.css" "$DOTFILES_DIR/ghostty/gtk.css"
    cp -f "$PRESET_DIR/hypr/hyprland.lua" "$DOTFILES_DIR/hypr/hyprland.lua"
    cp -f "$PRESET_DIR/noctalia/config.toml" "$DOTFILES_DIR/noctalia/config.toml"
fi

[[ -f "$PRESET_DIR/btop/btop.conf" ]] && cp -f "$PRESET_DIR/btop/btop.conf" "$CONFIG_DIR/btop/btop.conf"
[[ -f "$PRESET_DIR/ghostty/config.ghostty" ]] && cp -f "$PRESET_DIR/ghostty/config.ghostty" "$CONFIG_DIR/ghostty/config.ghostty"
[[ -f "$PRESET_DIR/ghostty/config.ghostty" ]] && cp -f "$PRESET_DIR/ghostty/config.ghostty" "$CONFIG_DIR/ghostty/config"
[[ -f "$PRESET_DIR/ghostty/gtk.css" ]] && cp -f "$PRESET_DIR/ghostty/gtk.css" "$CONFIG_DIR/ghostty/gtk.css"
[[ -f "$PRESET_DIR/hypr/hyprland.lua" ]] && cp -f "$PRESET_DIR/hypr/hyprland.lua" "$CONFIG_DIR/hypr/hyprland.lua"
[[ -f "$PRESET_DIR/noctalia/config.toml" ]] && cp -f "$PRESET_DIR/noctalia/config.toml" "$CONFIG_DIR/noctalia/config.toml"

# Apply target opacity across configs if in blur mode
if [[ "$MODE" == "blur" ]]; then
    # 1. Ghostty background-opacity
    if [[ -f "$CONFIG_DIR/ghostty/config.ghostty" ]]; then
        sed -i -E "s/(background-opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$CONFIG_DIR/ghostty/config.ghostty"
    fi
    if [[ -f "$CONFIG_DIR/ghostty/config" ]]; then
        sed -i -E "s/(background-opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$CONFIG_DIR/ghostty/config"
    fi

    # 2. Noctalia top bar & dock
    if [[ -f "$CONFIG_DIR/noctalia/config.toml" ]]; then
        sed -i -E "/\[bar\.default\]/,/\[/{ s/(background_opacity\s*=\s*)[0-9.]+/\1$OPACITY/; s/(capsule_opacity\s*=\s*)[0-9.]+/\1$OPACITY/ }" "$CONFIG_DIR/noctalia/config.toml"
        sed -i -E "/\[dock\]/,/\[/{ s/(background_opacity\s*=\s*)[0-9.]+/\1$OPACITY/ }" "$CONFIG_DIR/noctalia/config.toml"
    fi

    # 3. Hyprland compositor opacity
    if [[ -f "$CONFIG_DIR/hypr/hyprland.lua" ]]; then
        sed -i -E "s/(active_opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$CONFIG_DIR/hypr/hyprland.lua"
        sed -i -E "s/(inactive_opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$CONFIG_DIR/hypr/hyprland.lua"
        sed -i -E "s/opacity = \"[0-9.]+ [0-9.]+\"/opacity = \"$OPACITY $OPACITY\"/g" "$CONFIG_DIR/hypr/hyprland.lua"
    fi

    # Also sync into dotfiles if present
    if [[ -d "$DOTFILES_DIR" ]]; then
        [[ -f "$DOTFILES_DIR/ghostty/config.ghostty" ]] && sed -i -E "s/(background-opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$DOTFILES_DIR/ghostty/config.ghostty"
        if [[ -f "$DOTFILES_DIR/noctalia/config.toml" ]]; then
            sed -i -E "/\[bar\.default\]/,/\[/{ s/(background_opacity\s*=\s*)[0-9.]+/\1$OPACITY/; s/(capsule_opacity\s*=\s*)[0-9.]+/\1$OPACITY/ }" "$DOTFILES_DIR/noctalia/config.toml"
            sed -i -E "/\[dock\]/,/\[/{ s/(background_opacity\s*=\s*)[0-9.]+/\1$OPACITY/ }" "$DOTFILES_DIR/noctalia/config.toml"
        fi
        if [[ -f "$DOTFILES_DIR/hypr/hyprland.lua" ]]; then
            sed -i -E "s/(active_opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$DOTFILES_DIR/hypr/hyprland.lua"
            sed -i -E "s/(inactive_opacity\s*=\s*)[0-9.]+/\1$OPACITY/" "$DOTFILES_DIR/hypr/hyprland.lua"
            sed -i -E "s/opacity = \"[0-9.]+ [0-9.]+\"/opacity = \"$OPACITY $OPACITY\"/g" "$DOTFILES_DIR/hypr/hyprland.lua"
        fi
    fi
fi

# Update Noctalia state overrides if present
STATE_SETTINGS="$HOME/.local/state/noctalia/settings.toml"
if [[ -f "$STATE_SETTINGS" ]]; then
    if [[ "$MODE" == "default" ]]; then
        sed -i 's/settings_window_translucent = true/settings_window_translucent = false/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "glass"/transparency_mode = "solid"/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "soft"/transparency_mode = "solid"/g' "$STATE_SETTINGS"
        sed -i -E 's/(background_opacity\s*=\s*)[0-9.]+/\11.0/g' "$STATE_SETTINGS"
    else
        sed -i 's/settings_window_translucent = false/settings_window_translucent = true/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "solid"/transparency_mode = "glass"/g' "$STATE_SETTINGS"
        sed -i 's/transparency_mode = "soft"/transparency_mode = "glass"/g' "$STATE_SETTINGS"
        sed -i -E "s/(background_opacity\s*=\s*)[0-9.]+/\1$OPACITY/g" "$STATE_SETTINGS"
    fi
fi

# Reload Hyprland compositor
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# Refresh or ensure Noctalia desktop shell daemon
if [[ "$RESTART_NOCTALIA" == "true" ]]; then
    if pgrep -x noctalia >/dev/null 2>&1; then
        pkill -x noctalia 2>/dev/null || true
        wait_cycles=0
        while pgrep -x noctalia >/dev/null 2>&1; do
            sleep 0.05
            wait_cycles=$((wait_cycles + 1))
            if [[ $wait_cycles -ge 30 ]]; then
                pkill -9 -x noctalia 2>/dev/null || true
                break
            fi
        done
        sleep 0.2
    fi
    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl eval 'hl.exec_cmd("noctalia")' >/dev/null 2>&1 || setsid -f noctalia >/dev/null 2>&1 || true
    else
        setsid -f noctalia >/dev/null 2>&1 || true
    fi
elif pgrep -x noctalia >/dev/null 2>&1; then
    # Reload live daemon via IPC to update bar, dock, and surfaces instantly without dropping wallpaper or bar
    noctalia msg config-reload >/dev/null 2>&1 || true
    noctalia msg dock-reload >/dev/null 2>&1 || true
    noctalia msg templates-apply >/dev/null 2>&1 || true
    noctalia msg bar-show >/dev/null 2>&1 || true
    if command -v hyprctl >/dev/null 2>&1 && hyprctl clients 2>/dev/null | grep -q "class: dev\.noctalia\.Noctalia"; then
        noctalia msg settings-close >/dev/null 2>&1 || true
        noctalia msg settings-open >/dev/null 2>&1 || true
    fi
else
    # If not running, spawn cleanly under Hyprland compositor
    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl eval 'hl.exec_cmd("noctalia")' >/dev/null 2>&1 || setsid -f noctalia >/dev/null 2>&1 || true
    else
        setsid -f noctalia >/dev/null 2>&1 || true
    fi
fi

# Reload Ghostty terminal configuration
gdbus call --session --dest com.mitchellh.ghostty --object-path /com/mitchellh/ghostty --method org.gtk.Actions.Activate reload-config "[]" "{}" >/dev/null 2>&1 || pkill -SIGUSR2 ghostty 2>/dev/null || true

# Reload btop and Neovim
pkill -SIGUSR2 -x btop >/dev/null 2>&1 || true
pkill -SIGUSR1 -x nvim >/dev/null 2>&1 || true

if [[ "$MODE" == "default" ]]; then
    printf "[PASS] Hyprland profile switched to: default (solid opaque 1.0, blur disabled)\n"
else
    printf "[PASS] Hyprland profile switched to: blur (glassmorphism opacity %s, blur enabled)\n" "$OPACITY"
fi
