#!/usr/bin/env bash
# ==============================================================================
# kkhypr: Universal Installer and Symlink Deployment Engine
# Target: Fedora 44+, Hyprland 0.56+, Noctalia Shell v5, Ghostty
# Portable, Modular, and Hardware-Agnostic
# ==============================================================================

set -euo pipefail

# Script and dynamic path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$TARGET_HOME/.config}"
LOCAL_BIN="$TARGET_HOME/.local/bin"
LOCAL_LIB="$TARGET_HOME/.local/lib"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Operational modes
DRY_RUN=0
CHECK_ONLY=0
FORCE=0
DEPLOY_ALL=0
HYBRID_GPU=0
OPTIMIZE_SERVICES=0
SYSTEM_INSTALL=0

log_info() {
    printf "[INFO] %s\n" "$1"
}

log_warn() {
    printf "[WARN] %s\n" "$1" >&2
}

log_err() {
    printf "[ERROR] %s\n" "$1" >&2
}

log_pass() {
    printf "[PASS] %s\n" "$1"
}

usage() {
    cat << 'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --check              Run diagnostic validation on dependencies and configs only
  --dry-run            Simulate installation actions without modifying files
  --force              Overwrite existing targets if they are not matching symlinks
  --all                Deploy all application configurations regardless of installed binaries
  --hybrid-gpu         Deploy optional AMD+NVIDIA hybrid GPU isolation environment
  --optimize-services  Disable redundant Fedora services (ABRT, Rsyslog) to free RAM
  --system             Deploy system-wide environment drop-ins (requires sudo)
  --help               Show this help message
EOF
    exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --all)
            DEPLOY_ALL=1
            shift
            ;;
        --hybrid-gpu)
            HYBRID_GPU=1
            shift
            ;;
        --optimize-services)
            OPTIMIZE_SERVICES=1
            shift
            ;;
        --system)
            SYSTEM_INSTALL=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_err "Unknown argument: $1"
            usage
            ;;
    esac
done

detect_chassis() {
    if command -v hostnamectl >/dev/null 2>&1; then
        local h_chassis
        h_chassis="$(hostnamectl chassis 2>/dev/null || true)"
        if [[ "$h_chassis" =~ ^(laptop|notebook|convertible|portable)$ ]]; then
            echo "laptop"
            return 0
        elif [[ "$h_chassis" =~ ^(desktop|server|vm|container)$ ]]; then
            echo "desktop"
            return 0
        fi
    fi

    if [[ -f /sys/class/dmi/id/chassis_type ]]; then
        local ctype
        ctype="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)"
        if [[ "$ctype" =~ ^(8|9|10|11|14|30|31|32)$ ]]; then
            echo "laptop"
            return 0
        fi
    fi

    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
        echo "laptop"
        return 0
    fi

    echo "desktop"
}

check_binary() {
    local bin="$1"
    local required="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        log_pass "Found binary: $(command -v "$bin")"
        return 0
    fi

    if [[ "$required" == "true" ]]; then
        log_err "Missing required binary: $bin"
        return 1
    else
        log_warn "Optional binary not found: $bin"
        return 0
    fi
}

check_dependencies() {
    log_info "Verifying core dependencies..."
    local errors=0

    check_binary "hyprland" "true" || ((errors++))
    check_binary "noctalia" "true" || ((errors++))
    check_binary "ghostty" "true" || ((errors++))
    check_binary "hypridle" "true" || ((errors++))
    check_binary "hyprlock" "true" || ((errors++))
    check_binary "hyprpaper" "true" || ((errors++))
    check_binary "hyprland-dialog" "true" || ((errors++))
    check_binary "wpctl" "false" || true
    check_binary "brightnessctl" "false" || true
    check_binary "grim" "false" || true
    check_binary "slurp" "false" || true
    check_binary "wl-copy" "false" || true

    if ((errors > 0)); then
        log_err "Dependency check failed with $errors missing required packages."
        return 1
    fi
    log_pass "All core binaries verified."
    return 0
}

validate_configurations() {
    log_info "Validating configuration files..."
    local hypr_lua="$SCRIPT_DIR/dotfiles/hypr/hyprland.lua"
    local noctalia_conf="$SCRIPT_DIR/dotfiles/noctalia/config.toml"

    if [[ -f "$hypr_lua" ]]; then
        if hyprland --verify-config -c "$hypr_lua" >/dev/null 2>&1; then
            log_pass "Hyprland Lua config validation passed: $hypr_lua"
        else
            log_err "Hyprland Lua config validation failed: $hypr_lua"
            hyprland --verify-config -c "$hypr_lua"
            return 1
        fi
    fi

    if [[ -f "$noctalia_conf" ]]; then
        if noctalia config validate "$noctalia_conf" >/dev/null 2>&1; then
            log_pass "Noctalia config validation passed: $noctalia_conf"
        else
            log_err "Noctalia config validation failed: $noctalia_conf"
            noctalia config validate "$noctalia_conf"
            return 1
        fi
    fi
    return 0
}

check_hardware_topology() {
    local chassis
    chassis="$(detect_chassis)"
    log_info "Auditing system topology (Chassis: $chassis)..."

    local -a cards=(/dev/dri/card*)
    if [[ -e "${cards[0]}" ]]; then
        log_pass "Detected DRM GPU device nodes: ${cards[*]}"
    else
        log_warn "No DRM GPU device nodes detected in /dev/dri/"
    fi
}

deploy_link() {
    local source_path="$1"
    local target_path="$2"
    local target_parent
    target_parent="$(dirname "$target_path")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Symlink: $target_path -> $source_path"
        return 0
    fi

    mkdir -p "$target_parent"

    if [[ -L "$target_path" ]]; then
        local current_source
        current_source="$(readlink "$target_path")"
        if [[ "$current_source" == "$source_path" ]]; then
            log_pass "Up to date: $target_path"
            return 0
        fi
        log_info "Updating link: $target_path"
        rm -f "$target_path"
    elif [[ -e "$target_path" ]]; then
        if [[ "$FORCE" -eq 1 ]]; then
            local backup_path="${target_path}.backup.${TIMESTAMP}"
            log_warn "Moving existing file to backup: $backup_path"
            mv "$target_path" "$backup_path"
        else
            log_err "Target exists and is not a symlink: $target_path (use --force to backup and overwrite)"
            return 1
        fi
    fi

    ln -s "$source_path" "$target_path"
    log_pass "Linked: $target_path -> $source_path"
}

deploy_hard_link() {
    local source_path="$1"
    local target_path="$2"
    local target_parent
    target_parent="$(dirname "$target_path")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "[DRY-RUN] Hardlink: $target_path -> $source_path"
        return 0
    fi

    mkdir -p "$target_parent"

    if [[ -L "$target_path" ]]; then
        log_info "Replacing symlink with hardlink for inotify support: $target_path"
        rm -f "$target_path"
    elif [[ -e "$target_path" ]]; then
        if [[ "$(stat -c %i "$target_path" 2>/dev/null)" == "$(stat -c %i "$source_path" 2>/dev/null)" ]]; then
            log_pass "Up to date (hardlink): $target_path"
            return 0
        fi
        if [[ "$FORCE" -eq 1 ]]; then
            local backup_path="${target_path}.backup.${TIMESTAMP}"
            log_warn "Moving existing file to backup: $backup_path"
            mv "$target_path" "$backup_path"
        else
            rm -f "$target_path"
        fi
    fi

    ln "$source_path" "$target_path"
    log_pass "Hardlinked: $target_path -> $source_path"
}

deploy_app() {
    local bin="$1"
    local name="$2"
    shift 2
    if command -v "$bin" >/dev/null 2>&1 || [[ "$DEPLOY_ALL" -eq 1 ]]; then
        log_info "Configuring $name..."
        "$@"
    else
        log_info "Skipping $name ($bin not found, pass --all to deploy anyway)"
    fi
}

deploy_hypridle_config() {
    local chassis="$1"
    local target="$CONFIG_DIR/hypr/hypridle.conf"

    if [[ "$chassis" == "laptop" ]]; then
        deploy_link "$SCRIPT_DIR/dotfiles/hypr/hypridle.conf" "$target"
    else
        log_info "Configuring desktop power idle profile (without laptop backlight dimming)..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log_info "[DRY-RUN] Generate desktop hypridle: $target"
            return 0
        fi
        mkdir -p "$CONFIG_DIR/hypr"
        sed '/# Idle dimming/,+4d' "$SCRIPT_DIR/dotfiles/hypr/hypridle.conf" > "$target.tmp"
        mv "$target.tmp" "$target"
        log_pass "Deployed desktop hypridle profile: $target"
    fi
}

deploy_configurations() {
    log_info "Deploying core desktop and toolkit configurations..."
    local chassis
    chassis="$(detect_chassis)"

    # Core Hyprland ecosystem
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprland.lua" "$CONFIG_DIR/hypr/hyprland.lua"
    if [[ -L "$CONFIG_DIR/hypr/hyprland.conf" && ! -e "$CONFIG_DIR/hypr/hyprland.conf" ]]; then
        rm -f "$CONFIG_DIR/hypr/hyprland.conf"
    fi
    deploy_hypridle_config "$chassis"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprlock.conf" "$CONFIG_DIR/hypr/hyprlock.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprpaper.conf" "$CONFIG_DIR/hypr/hyprpaper.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/noctalia.lua" "$CONFIG_DIR/hypr/noctalia.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/scripts/compact_workspaces.py" "$CONFIG_DIR/hypr/scripts/compact_workspaces.py"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/scripts/screenshot.sh" "$CONFIG_DIR/hypr/scripts/screenshot.sh"

    # Noctalia desktop shell
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/config.toml" "$CONFIG_DIR/noctalia/config.toml"
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/palettes/noctalia.json" "$CONFIG_DIR/noctalia/palettes/noctalia.json"
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/colors.json" "$CONFIG_DIR/noctalia/colors.json"
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/plugins" "$CONFIG_DIR/noctalia/plugins"
    mkdir -p "$CONFIG_DIR/noctalia/scripts"
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/scripts/sync-gtk-theme.sh" "$CONFIG_DIR/noctalia/scripts/sync-gtk-theme.sh"
    chmod +x "$SCRIPT_DIR/dotfiles/noctalia/scripts/sync-gtk-theme.sh"
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/scripts/toggle-emoji.sh" "$CONFIG_DIR/noctalia/scripts/toggle-emoji.sh"
    chmod +x "$SCRIPT_DIR/dotfiles/noctalia/scripts/toggle-emoji.sh"

    # GTK3 and GTK4 dynamic Noctalia theming
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-3.0/gtk-dark.css" "$CONFIG_DIR/gtk-3.0/gtk-dark.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-3.0/noctalia.css" "$CONFIG_DIR/gtk-3.0/noctalia.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-3.0/settings.ini" "$CONFIG_DIR/gtk-3.0/settings.ini"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-4.0/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-4.0/gtk-dark.css" "$CONFIG_DIR/gtk-4.0/gtk-dark.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-4.0/noctalia.css" "$CONFIG_DIR/gtk-4.0/noctalia.css"
    deploy_link "$SCRIPT_DIR/dotfiles/gtk-4.0/settings.ini" "$CONFIG_DIR/gtk-4.0/settings.ini"

    # Compile and install GTK real-time stylesheet hot-reload shim
    mkdir -p "$LOCAL_LIB"
    if command -v gcc >/dev/null 2>&1; then
        local cflags_libs
        cflags_libs=$(pkg-config --cflags --libs gio-2.0 glib-2.0 2>/dev/null || true)
        # shellcheck disable=SC2086
        gcc -shared -fPIC -O2 -Wall -Wextra "$SCRIPT_DIR/dotfiles/gtk/libgtk-live-reload.c" -o "$SCRIPT_DIR/dotfiles/gtk/libgtk-live-reload.so" -ldl $cflags_libs 2>/dev/null || true
    fi
    if [[ -f "$SCRIPT_DIR/dotfiles/gtk/libgtk-live-reload.so" ]]; then
        install -m 755 "$SCRIPT_DIR/dotfiles/gtk/libgtk-live-reload.so" "$LOCAL_LIB/libgtk-live-reload.so"
        log_pass "Installed GTK live stylesheet reload shim ($LOCAL_LIB/libgtk-live-reload.so)"
    fi

    # Systemd session target and user environment
    deploy_link "$SCRIPT_DIR/dotfiles/systemd/user/hyprland-session.target" "$CONFIG_DIR/systemd/user/hyprland-session.target"
    deploy_link "$SCRIPT_DIR/system/environment.d/20-gtk-theme.conf" "$CONFIG_DIR/environment.d/20-gtk-theme.conf"

    if [[ "$HYBRID_GPU" -eq 1 ]]; then
        deploy_link "$SCRIPT_DIR/system/environment.d/10-vulkan-hybrid.conf" "$CONFIG_DIR/environment.d/10-vulkan-hybrid.conf"
        log_pass "Deployed hybrid GPU isolation environment drop-in"
    fi

    # Modular Application Deployment
    deploy_app "ghostty" "Ghostty Terminal" _deploy_ghostty
    deploy_app "btop" "btop System Monitor" _deploy_btop
    deploy_app "nvim" "Neovim" _deploy_nvim
    deploy_app "zed" "Zed Editor" _deploy_zed
    deploy_app "code" "VS Code" _deploy_vscode
    deploy_app "codium" "VSCodium" _deploy_vscodium
    deploy_app "wpctl" "WirePlumber Bluetooth Policy" _deploy_wireplumber
}

_deploy_ghostty() {
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/config.ghostty" "$CONFIG_DIR/ghostty/config.ghostty"
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/gtk.css" "$CONFIG_DIR/ghostty/gtk.css"
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/themes/noctalia" "$CONFIG_DIR/ghostty/themes/noctalia"
    mkdir -p "$LOCAL_BIN"
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/scripts/ghostty-theme" "$LOCAL_BIN/ghostty-theme"
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/scripts/ghostty-theme" "$LOCAL_BIN/term-theme"
}

_deploy_btop() {
    deploy_link "$SCRIPT_DIR/dotfiles/btop/btop.conf" "$CONFIG_DIR/btop/btop.conf"
}

_deploy_nvim() {
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/init.lua" "$CONFIG_DIR/nvim/init.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lazy-lock.json" "$CONFIG_DIR/nvim/lazy-lock.json"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/lazy.lua" "$CONFIG_DIR/nvim/lua/config/lazy.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/options.lua" "$CONFIG_DIR/nvim/lua/config/options.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/keymaps.lua" "$CONFIG_DIR/nvim/lua/config/keymaps.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/colorscheme.lua" "$CONFIG_DIR/nvim/lua/plugins/colorscheme.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/treesitter.lua" "$CONFIG_DIR/nvim/lua/plugins/treesitter.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/base16.lua" "$CONFIG_DIR/nvim/lua/plugins/base16.lua"
}

_deploy_zed() {
    deploy_link "$SCRIPT_DIR/dotfiles/zed/settings.json" "$CONFIG_DIR/zed/settings.json"
    deploy_link "$SCRIPT_DIR/dotfiles/zed/keymap.json" "$CONFIG_DIR/zed/keymap.json"
    deploy_link "$SCRIPT_DIR/dotfiles/zed/tasks.json" "$CONFIG_DIR/zed/tasks.json"
    deploy_hard_link "$SCRIPT_DIR/dotfiles/zed/themes/noctalia.json" "$CONFIG_DIR/zed/themes/noctalia.json"
}

_deploy_vscode() {
    deploy_link "$SCRIPT_DIR/dotfiles/vscode/settings.json" "$CONFIG_DIR/Code/User/settings.json"
}

_deploy_vscodium() {
    deploy_link "$SCRIPT_DIR/dotfiles/vscodium/settings.json" "$CONFIG_DIR/VSCodium/User/settings.json"
}

_deploy_wireplumber() {
    deploy_link "$SCRIPT_DIR/dotfiles/wireplumber/wireplumber.conf.d/50-bluez.conf" "$CONFIG_DIR/wireplumber/wireplumber.conf.d/50-bluez.conf"
}

optimize_services() {
    log_info "Optimizing Fedora background services..."
    local -a services=(
        "abrtd.service"
        "abrt-journal-core.service"
        "abrt-oops.service"
        "abrt-xorg.service"
        "rsyslog.service"
    )

    if [[ "$DRY_RUN" -eq 1 ]]; then
        for svc in "${services[@]}"; do
            log_info "[DRY-RUN] Would disable service: $svc"
        done
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warn "systemctl not found. Skipping service optimization."
        return 0
    fi

    log_info "Disabling redundant crash reporting (ABRT) and legacy syslog daemons to reclaim ~246 MB RAM..."
    local -a to_disable=()
    for svc in "${services[@]}"; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
            to_disable+=("$svc")
        else
            log_info "Service not present, skipping: $svc"
        fi
    done

    if [[ ${#to_disable[@]} -gt 0 ]]; then
        if sudo systemctl disable --now "${to_disable[@]}"; then
            log_pass "Redundant background services disabled successfully: ${to_disable[*]}"
        else
            log_warn "Failed to disable some services. Check permissions or service state."
        fi
    else
        log_pass "No targeted redundant services found or already removed."
    fi
}

deploy_system() {
    log_info "Deploying system-level environment drop-ins..."

    if [[ "$EUID" -ne 0 ]]; then
        log_err "System configuration requires root privileges. Please re-run with: sudo $0 --system"
        return 1
    fi

    local env_dir="/etc/environment.d"
    mkdir -p "$env_dir"

    cp "$SCRIPT_DIR/system/environment.d/20-gtk-theme.conf" "$env_dir/20-gtk-theme.conf"
    chmod 644 "$env_dir/20-gtk-theme.conf"
    log_pass "Deployed system-wide GTK theme environment: $env_dir/20-gtk-theme.conf"

    if [[ "$HYBRID_GPU" -eq 1 ]]; then
        local env_target="$env_dir/10-vulkan-hybrid.conf"
        cp "$SCRIPT_DIR/system/environment.d/10-vulkan-hybrid.conf" "$env_target"
        chmod 644 "$env_target"
        log_pass "Deployed system-wide Vulkan hybrid GPU isolation environment: $env_target"
    fi

    systemctl daemon-reload
    log_pass "Reloaded systemd daemon"
}

main() {
    if [[ "$SYSTEM_INSTALL" -eq 1 ]]; then
        deploy_system
        exit 0
    fi

    log_info "Starting kkhypr universal installer (User: $TARGET_USER, Home: $TARGET_HOME)..."

    check_dependencies
    validate_configurations
    check_hardware_topology

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_pass "Check completed successfully. No changes made."
        exit 0
    fi

    deploy_configurations
    deploy_appearance_profiles

    if [[ "$OPTIMIZE_SERVICES" -eq 1 ]]; then
        optimize_services
    fi

    log_pass "Deployment finished successfully."
    log_info "To test Hyprland, log out and select 'Hyprland' in your display manager session menu."
}

deploy_appearance_profiles() {
    log_info "Deploying hypr-default and hypr-blur profile switchers..."
    mkdir -p "$LOCAL_BIN"

    deploy_link "$SCRIPT_DIR/scripts/hypr-profile.sh" "$LOCAL_BIN/hypr-profile.sh"

    cat << 'EOF' > "$LOCAL_BIN/hypr-default"
#!/usr/bin/env bash
exec hypr-profile.sh default "$@"
EOF
    chmod +x "$LOCAL_BIN/hypr-default"

    cat << 'EOF' > "$LOCAL_BIN/hypr-blur"
#!/usr/bin/env bash
exec hypr-profile.sh blur "$@"
EOF
    chmod +x "$LOCAL_BIN/hypr-blur"

    # Shell aliases deployment across bash, zsh, and fish
    local bashrc="$TARGET_HOME/.bashrc"
    if [[ -L "$bashrc" && ! -e "$bashrc" ]]; then
        rm -f "$bashrc"
        if [[ -f /etc/skel/.bashrc ]]; then
            cp /etc/skel/.bashrc "$bashrc"
        else
            touch "$bashrc"
        fi
    fi
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "alias hypr-default=" "$bashrc"; then
            printf "\n# Hyprland appearance profile switchers\nalias hypr-default='hypr-profile.sh default'\nalias hypr-blur='hypr-profile.sh blur'\n" >> "$bashrc"
            log_pass "Configured aliases in: $bashrc"
        fi
    fi

    local zshrc="$TARGET_HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        if ! grep -q "alias hypr-default=" "$zshrc"; then
            printf "\n# Hyprland appearance profile switchers\nalias hypr-default='hypr-profile.sh default'\nalias hypr-blur='hypr-profile.sh blur'\n" >> "$zshrc"
            log_pass "Configured aliases in: $zshrc"
        fi
    fi

    local fish_conf="$CONFIG_DIR/fish/config.fish"
    if [[ -f "$fish_conf" ]]; then
        if ! grep -q "alias hypr-default" "$fish_conf"; then
            printf "\n# Hyprland appearance profile switchers\nalias hypr-default 'hypr-profile.sh default'\nalias hypr-blur 'hypr-profile.sh blur'\n" >> "$fish_conf"
            log_pass "Configured aliases in: $fish_conf"
        fi
    fi
}

main
