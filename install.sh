#!/usr/bin/env bash
# ==============================================================================
# kkhypr: Installer and Symlink Deployment Engine
# Target: Fedora 44+, Hyprland 0.56+, Noctalia Shell v5, Ghostty
# ==============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Modes
DRY_RUN=0
CHECK_ONLY=0
FORCE=0
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
  --optimize-services  Disable redundant Fedora services (ABRT, Rsyslog) to free RAM
  --system             Deploy system-wide GPU isolation and GDM audio conflict fixes (requires sudo)
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
    local hypr_conf="$SCRIPT_DIR/dotfiles/hypr/hyprland.conf"
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

    if [[ -f "$hypr_conf" ]]; then
        if hyprland --verify-config -c "$hypr_conf" >/dev/null 2>&1; then
            log_pass "Hyprland config validation passed: $hypr_conf"
        else
            log_err "Hyprland config validation failed: $hypr_conf"
            hyprland --verify-config -c "$hypr_conf"
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
    log_info "Auditing GPU hardware routing..."
    local igpu_path="/dev/dri/card1"
    local dgpu_path="/dev/dri/card0"

    if [[ -e "$igpu_path" ]]; then
        log_pass "Primary AMD iGPU DRM node confirmed at $igpu_path"
    else
        log_warn "Primary AMD iGPU DRM node not found at expected path: $igpu_path"
    fi

    if [[ -e "$dgpu_path" ]]; then
        log_info "Secondary NVIDIA dGPU DRM node confirmed at $dgpu_path"
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

deploy_configurations() {
    log_info "Deploying configuration symlinks..."

    # Hyprland ecosystem
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprland.lua" "$CONFIG_DIR/hypr/hyprland.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hypridle.conf" "$CONFIG_DIR/hypr/hypridle.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprlock.conf" "$CONFIG_DIR/hypr/hyprlock.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/hyprpaper.conf" "$CONFIG_DIR/hypr/hyprpaper.conf"
    deploy_link "$SCRIPT_DIR/dotfiles/hypr/scripts/compact_workspaces.py" "$CONFIG_DIR/hypr/scripts/compact_workspaces.py"

    # Noctalia shell
    deploy_link "$SCRIPT_DIR/dotfiles/noctalia/config.toml" "$CONFIG_DIR/noctalia/config.toml"

    # Ghostty terminal
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/config.ghostty" "$CONFIG_DIR/ghostty/config.ghostty"
    deploy_link "$SCRIPT_DIR/dotfiles/ghostty/gtk.css" "$CONFIG_DIR/ghostty/gtk.css"

    # WirePlumber audio and bluetooth policy
    deploy_link "$SCRIPT_DIR/dotfiles/wireplumber/wireplumber.conf.d/50-bluez.conf" "$CONFIG_DIR/wireplumber/wireplumber.conf.d/50-bluez.conf"

    # Neovim (Catppuccin Mocha + transparent background)
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/init.lua" "$CONFIG_DIR/nvim/init.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lazy-lock.json" "$CONFIG_DIR/nvim/lazy-lock.json"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/lazy.lua" "$CONFIG_DIR/nvim/lua/config/lazy.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/options.lua" "$CONFIG_DIR/nvim/lua/config/options.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/config/keymaps.lua" "$CONFIG_DIR/nvim/lua/config/keymaps.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/colorscheme.lua" "$CONFIG_DIR/nvim/lua/plugins/colorscheme.lua"
    deploy_link "$SCRIPT_DIR/dotfiles/nvim/lua/plugins/treesitter.lua" "$CONFIG_DIR/nvim/lua/plugins/treesitter.lua"

    # VS Code & VSCodium (Catppuccin Mocha + glassmorphism/blur)
    deploy_link "$SCRIPT_DIR/dotfiles/vscode/settings.json" "$CONFIG_DIR/Code/User/settings.json"
    deploy_link "$SCRIPT_DIR/dotfiles/vscodium/settings.json" "$CONFIG_DIR/VSCodium/User/settings.json"

    # Zed Editor (Catppuccin Mocha + background opacity & blur)
    deploy_link "$SCRIPT_DIR/dotfiles/zed/settings.json" "$CONFIG_DIR/zed/settings.json"
    deploy_link "$SCRIPT_DIR/dotfiles/zed/keymap.json" "$CONFIG_DIR/zed/keymap.json"
    deploy_link "$SCRIPT_DIR/dotfiles/zed/tasks.json" "$CONFIG_DIR/zed/tasks.json"
    deploy_link "$SCRIPT_DIR/dotfiles/zed/themes/catppuccin.json" "$CONFIG_DIR/zed/themes/catppuccin.json"

    # Systemd session target and environment drop-in
    deploy_link "$SCRIPT_DIR/dotfiles/systemd/user/hyprland-session.target" "$CONFIG_DIR/systemd/user/hyprland-session.target"
    deploy_link "$SCRIPT_DIR/system/environment.d/10-vulkan-hybrid.conf" "$CONFIG_DIR/environment.d/10-vulkan-hybrid.conf"

    if [[ ! -f "/etc/environment.d/10-vulkan-hybrid.conf" ]]; then
        log_warn "System-wide GPU isolation missing (/etc/environment.d/10-vulkan-hybrid.conf). Run 'sudo ./install.sh --system' to apply."
    fi
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
    log_info "Deploying system-level GPU isolation and audio conflict fixes..."

    if [[ "$EUID" -ne 0 ]]; then
        log_err "System configuration requires root privileges. Please re-run with: sudo $0 --system"
        return 1
    fi

    # 1. System-wide Vulkan and GPU environment isolation
    local env_dir="/etc/environment.d"
    local env_target="$env_dir/10-vulkan-hybrid.conf"
    mkdir -p "$env_dir"
    cp "$SCRIPT_DIR/system/environment.d/10-vulkan-hybrid.conf" "$env_target"
    chmod 644 "$env_target"
    log_pass "Deployed system-wide Vulkan isolation environment: $env_target"

    # 2. Prevent GDM greeter and system users from starting PipeWire / WirePlumber
    local systemd_user_dir="/etc/systemd/user"
    local dropin_src="$SCRIPT_DIR/system/systemd/user/10-disable-greeter.conf"
    local -a service_dropin_dirs=(
        "$systemd_user_dir/pipewire.socket.d"
        "$systemd_user_dir/pipewire.service.d"
        "$systemd_user_dir/pipewire-pulse.socket.d"
        "$systemd_user_dir/pipewire-pulse.service.d"
        "$systemd_user_dir/wireplumber.service.d"
    )

    for dir in "${service_dropin_dirs[@]}"; do
        mkdir -p "$dir"
        cp "$dropin_src" "$dir/10-disable-greeter.conf"
        chmod 644 "$dir/10-disable-greeter.conf"
    done
    log_pass "Deployed systemd user drop-ins to prevent GDM greeter audio contention"

    # 3. Optimize BlueZ Bluetooth policy for rapid reconnection
    if [[ -f "/etc/bluetooth/main.conf" ]]; then
        python3 -c '
import re
path = "/etc/bluetooth/main.conf"
with open(path) as f:
    text = f.read()

settings = {
    "AutoEnable": "true",
    "FastConnectable": "true",
    "ReconnectAttempts": "7",
    "ReconnectIntervals": "1, 2, 4, 8, 16, 32, 64"
}

match = re.search(r"(\[Policy\]\n)(.*?)(\n\[|\Z)", text, re.DOTALL)
if match:
    header, body, trailer = match.group(1), match.group(2), match.group(3)
    lines = body.splitlines()
    new_lines = []
    handled = set()
    for line in lines:
        stripped = line.strip()
        found_k = None
        for k in settings:
            if stripped.startswith(k) or stripped.startswith("#" + k) or stripped.startswith("# " + k):
                found_k = k
                break
        if found_k:
            if found_k not in handled:
                new_lines.append(f"{found_k} = {settings[found_k]}")
                handled.add(found_k)
        else:
            new_lines.append(line)
    for k, v in settings.items():
        if k not in handled:
            new_lines.append(f"{k} = {v}")
    new_text = text[:match.start()] + header + "\n".join(new_lines) + trailer + text[match.end():]
    with open(path, "w") as f:
        f.write(new_text)
'
        log_pass "Configured /etc/bluetooth/main.conf Policy parameters"
    fi

    # 4. Remove obsolete GDM user WirePlumber configuration if present
    if [[ -f "/var/lib/gdm/.config/wireplumber/wireplumber.conf.d/disable-bluetooth.conf" ]]; then
        rm -f "/var/lib/gdm/.config/wireplumber/wireplumber.conf.d/disable-bluetooth.conf"
        log_pass "Removed obsolete GDM user WirePlumber configuration"
    fi

    # 5. Reload systemd daemon
    systemctl daemon-reload
    log_pass "Reloaded systemd daemon"
}

main() {
    if [[ "$SYSTEM_INSTALL" -eq 1 ]]; then
        deploy_system
        exit 0
    fi

    log_info "Starting kkhypr deployment script..."

    check_dependencies
    validate_configurations
    check_hardware_topology

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_pass "Check completed successfully. No changes made."
        exit 0
    fi

    deploy_configurations

    if [[ "$OPTIMIZE_SERVICES" -eq 1 ]]; then
        optimize_services
    fi

    log_pass "Deployment finished successfully."
    log_info "To test Hyprland, log out and select 'Hyprland' in your display manager session menu."
}

main
