# Architecture and Engineering Design

This document details the system design, hardware routing, daemon architecture, and compositor integration powering `kkhypr`.

---

## 1. Multi-GPU Zero-Freeze DRM Routing

Modern gaming and creator laptops pair an energy-efficient integrated GPU (iGPU) with a high-draw discrete graphics processor (dGPU). On the target reference hardware (AMD Ryzen 5 7535HS with Radeon 680M iGPU and NVIDIA GeForce RTX 2050 Mobile dGPU), the Linux kernel DRM subsystem frequently assigns:
* `/dev/dri/card0`: Discrete NVIDIA RTX 2050
* `/dev/dri/card1`: Integrated AMD Radeon 680M

Under standard Wayland compositors and GTK4/Libadwaita applications, launching any desktop application triggers Vulkan ICD discovery and DRM card enumeration. This probes `/dev/dri/card0`, waking the NVIDIA dGPU from ACPI D3cold power state into full D0 operating mode. This transition introduces a jarring 2 to 3 second micro-freeze across the entire desktop.

`kkhypr` eliminates these freezes through two deterministic environment rules:

### A. Explicit DRM Card Ordering
```ini
AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0
```
This binds the Aquamarine compositor backend directly to the integrated AMD Radeon 680M (`card1`) for all primary display presentation and composition. The discrete NVIDIA controller (`card0`) remains strictly secondary and stays powered down in ACPI D3cold until explicitly requested via prime offload. Note that Aquamarine uses colon delimiters to split device paths. PCI by-path identifiers containing colons must not be used.

### B. Vulkan ICD Loader Filtration
```ini
VK_LOADER_DRIVERS_SELECT=*radeon*
```
Standard Vulkan loaders enumerate all installed ICD drivers on disk upon initial context creation. Restricting the pattern to Mesa Radeon drivers guarantees that UI toolkits such as GTK4, Libadwaita, and Chromium do not probe the NVIDIA proprietary driver during window initialization.

### C. Acceleration Environment Variables
The environment configuration enforces hardware-accelerated decoding and 2D rendering through Mesa:
```ini
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
__GLX_VENDOR_LIBRARY_NAME=mesa
```

---

## 2. Configuration Architecture: Native Lua vs Legacy

Hyprland 0.56 introduces native Lua configuration support, providing full programmatic flexibility, structured types, loops, and conditional execution.

`kkhypr` maintains two configuration definitions:
1. `dotfiles/hypr/hyprland.lua`: The primary, modern Lua configuration. Utilizes `hl.config()`, `hl.bind()`, `hl.monitor()`, `hl.animation()`, and `hl.layer_rule()` for clean, type-safe compositor definition.
2. `dotfiles/hypr/hyprland.conf`: The verified legacy fallback configuration, guaranteeing 100% feature parity and backward compatibility across standard Hyprland releases.

Both files are continuously validated during continuous integration and pre-deployment checks via `hyprland --verify-config`.

---

## 3. Noctalia Desktop Shell v5 Integration

`kkhypr` integrates [Noctalia Desktop Shell v5](https://noctalia.dev) for desktop surface components:
* Top bar with battery, network, clock, and weather widgets.
* Dynamic application search launcher (`noctalia msg panel-toggle launcher`).
* Centralized quick settings and notifications panel (`noctalia msg panel-toggle control-center`).
* Native clipboard history overlay (`noctalia msg panel-toggle clipboard`).
* Hardware OSD indicators for volume, microphone, and backlight brightness.

### Custom Luau Plugins
Custom widgets are located in `dotfiles/noctalia/plugins/custom_bar/`:
* `laptop_battery.luau`: Native laptop battery cell telemetry with vertical fill icons.
* `bt_battery.luau`: Bluetooth peripheral battery telemetry reading live status via D-Bus.

---

## 4. Automated Noctalia Dynamic Theming Architecture

Color management across the desktop environment is fully automated by Noctalia Desktop Shell. Rather than manually editing theme files or maintaining static palette configurations for individual applications, Noctalia operates a built-in and community template processor.

### Dynamic Generation Pipeline
When a palette (such as Catppuccin, Tokyo Night, or wallpaper-derived colors) is selected in Noctalia Settings or triggered via `noctalia msg templates-apply`, Noctalia renders dynamic theme definitions into target application paths:

1. **Hyprland Compositor Borders**:
   Renders `$XDG_CONFIG_HOME/hypr/noctalia.lua`. The native compositor configuration `dotfiles/hypr/hyprland.lua` invokes `require("noctalia").apply_theme()`, instantly applying active and inactive window borders, group titles, and accent colors without restarting Hyprland.

2. **Ghostty Terminal**:
   Renders `/usr/share/noctalia/assets/templates/ghostty/ghostty` into `$XDG_CONFIG_HOME/ghostty/themes/noctalia`. The primary terminal configuration `dotfiles/ghostty/config.ghostty` references `theme = noctalia`, and running instances reload colors on the fly via D-Bus notifications.

3. **GTK 3 and GTK 4 Desktop Applications**:
   Renders `$XDG_CONFIG_HOME/gtk-3.0/noctalia.css` and `$XDG_CONFIG_HOME/gtk-4.0/noctalia.css`. Both `dotfiles/gtk-3.0/gtk.css` and `dotfiles/gtk-4.0/gtk.css` import this file directly, providing dynamic `@window_bg_color`, `@accent_color`, and `@headerbar_bg_color` values to all GTK applications, including GNOME Clocks.

4. **Zed Editor**:
   Renders `$XDG_CONFIG_HOME/zed/themes/noctalia.json`, defining `Noctalia Dark` and `Noctalia Light`. Deployed via a filesystem hardlink to the repository dotfile so Linux inotify watchers on the themes directory fire immediately upon template generation, enabling instant live updates without requiring an editor restart. `dotfiles/zed/settings.json` activates these themes directly.

5. **VS Code and VSCodium**:
   Updates `NoctaliaTheme-color-theme.json` inside the installed Noctalia Theme extension. With `workbench.colorTheme` set to `NoctaliaTheme`, editor syntax and UI accents automatically reflect the active desktop palette.

6. **Neovim and Terminal Utilities**:
   Generates `$XDG_CONFIG_HOME/nvim/lua/matugen.lua` for base16 Neovim theming, as well as template outputs for Kitty, Alacritty, Foot, Fuzzel, Rofi, Fastfetch, Bat, and Yazi.

---

## 5. Background Daemons and Services

### Dynamic Workspace Compactor (`compact_workspaces.py`)
In standard Hyprland setups, closing windows can leave sparse or empty workspaces (such as workspaces 1, 3, and 7 remaining open). `compact_workspaces.py` connects to Hyprland's UNIX event socket (`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`). Upon detecting `closewindow` or `destroyworkspace` events, the daemon shifts occupied workspaces downward into a contiguous sequence, preventing fragmented desktop states.

### Bluetooth Battery Telemetry Daemon (`bt_battery_sync.py`)
Listens to BlueZ D-Bus property changes for connected Bluetooth peripherals and updates telemetry state for the custom Noctalia top bar widget.

### Idle and Power Daemons
* `hypridle`: Handles screen dimming, lockscreen triggering via `hyprlock`, display power management signaling (DPMS off), and system suspend timeouts.
* `hyprlock`: Fast, PAM-authenticated Wayland lockscreen with blurred screen background caching.
* `hyprpaper`: Lightweight Wayland wallpaper utility handling smooth transitions.

### Fedora Background Service Optimization (ABRT and Rsyslog)
Fedora Workstation defaults include background systemd services designed for corporate workstation crash collection and legacy syslog aggregation. In an optimized tiling compositor environment, these daemons introduce unnecessary resident memory consumption:
* `abrtd.service`, `abrt-journal-core.service`, `abrt-oops.service`, `abrt-xorg.service`: The Red Hat Automatic Bug Reporting Tool daemons remain resident in memory (~190 MB total RSS) to generate Red Hat Bugzilla crash packages.
* `rsyslog.service`: Legacy syslog daemon (~56 MB RSS). This service is entirely redundant because `systemd-journald` natively handles all structured binary log capture, querying (`journalctl`), and persistence.

Disabling both services immediately reclaims ~246 MB of physical RAM without degrading any desktop capabilities:
```bash
sudo systemctl disable --now abrtd.service abrt-journal-core.service abrt-oops.service abrt-xorg.service
sudo systemctl disable --now rsyslog.service
```

---

## 6. Systemd User Session Integration

Session initialization is managed through systemd user targets located in `dotfiles/systemd/user/`:
* `hyprland-session.target`: Binds to `graphical-session.target` to ensure user services start in an orderly fashion after environment variables are imported to D-Bus and systemd.
* `hyprland-workspace-compactor.service`: Supervised background service for the workspace compactor daemon.
* `hyprland-bt-battery.service`: Supervised background service for the Bluetooth telemetry daemon.
