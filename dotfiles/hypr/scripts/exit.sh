#!/usr/bin/env bash
# ==============================================================================
# Hyprland Clean Session Teardown
# ==============================================================================
# Stop Hyprland and generic graphical session targets before compositor exit
# to ensure GDM/systemd user manager enters a clean state for subsequent logins.

systemctl --user stop hyprland-session.target graphical-session.target 2>/dev/null || true
systemctl --user unset-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE AQ_DRM_DEVICES 2>/dev/null || true

# Terminate compositor cleanly
exec hyprctl dispatch exit
