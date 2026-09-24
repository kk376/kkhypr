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
  --check        Run diagnostic validation on dependencies and configs only
  --dry-run      Simulate installation actions without modifying files
  --force        Overwrite existing targets if they are not matching symlinks
  --help         Show this help message
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

    # Systemd session target and environment drop-in
    deploy_link "$SCRIPT_DIR/dotfiles/systemd/user/hyprland-session.target" "$CONFIG_DIR/systemd/user/hyprland-session.target"
    deploy_link "$SCRIPT_DIR/system/environment.d/10-vulkan-hybrid.conf" "$CONFIG_DIR/environment.d/10-vulkan-hybrid.conf"
}

main() {
    log_info "Starting kkhypr deployment script..."

    check_dependencies
    validate_configurations
    check_hardware_topology

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_pass "Check completed successfully. No changes made."
        exit 0
    fi

    deploy_configurations
    log_pass "Deployment finished successfully."
    log_info "To test Hyprland, log out and select 'Hyprland' in your display manager session menu."
}

main
