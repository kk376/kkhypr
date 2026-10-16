# Architecture and Engineering Design

This document details the system design, hardware routing, daemon architecture, and compositor integration powering `kkhypr`.

---

## 1. Universal Hardware Architecture and Device Extension Hook

`kkhypr` is designed to be completely hardware-agnostic, running reliably on desktops, laptops, Intel graphics, AMD Radeon, and NVIDIA systems.

### A. Automatic Preferred Display Configuration
By default, `dotfiles/hypr/hyprland.lua` configures universal display auto-detection:
```lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
```
This guarantees that external monitors, ultrawide panels, and internal laptop screens initialize at native capability without manual editing.

### B. Machine-Specific Device Hook (`device.lua`)
For systems requiring custom hardware-level configuration, `dotfiles/hypr/hyprland.lua` provides an extension hook:
```lua
local device_override = os.getenv("HOME") .. "/.config/hypr/device.lua"
local dev_file = io.open(device_override, "r")
if dev_file then
    dev_file:close()
    pcall(dofile, device_override)
end
```
When present, `~/.config/hypr/device.lua` can define explicit panel refresh rates, fractional scaling (e.g. 1.25x for 1080p 15.6" screens), or multi-GPU Aquamarine DRM device strings without modifying the upstream dotfiles.

### C. Hardware Overrides & Multi-GPU Configuration
`kkhypr` contains zero hardcoded vendor driver paths or GPU bus IDs in its master configuration. The Linux kernel, Mesa DRM, and Vulkan loader auto-detect display hardware across Intel, AMD, NVIDIA, and virtual machines.

For hybrid laptops pairing integrated graphics with discrete GPUs, users who experience unexpected dGPU wakeups during desktop Vulkan or DRM scans can isolate rendering by defining environment variables in `~/.config/hypr/device.lua`. Full technical details and recipes are documented in [docs/HARDWARE_DRM.md](HARDWARE_DRM.md).

---

## 2. Configuration Architecture: Native Lua Engine

Hyprland 0.56 introduces native Lua configuration support, providing full programmatic flexibility, structured types, loops, and conditional execution.

`kkhypr` leverages `dotfiles/hypr/hyprland.lua` as its single, modular master configuration. Utilizes `hl.config()`, `hl.bind()`, `hl.monitor()`, `hl.animation()`, and `hl.layer_rule()` for clean, type-safe compositor definition. The configuration is validated continuously during continuous integration and pre-deployment checks via `hyprland --verify-config`.

---

## 3. Noctalia Desktop Shell v5 Integration

`kkhypr` integrates [Noctalia Desktop Shell v5](https://noctalia.dev) for desktop surface components:
* Top bar with battery, network, clock, and weather widgets.
* Dynamic application search launcher (`noctalia msg panel-toggle launcher`).
* Centralized quick settings and notifications panel (`noctalia msg panel-toggle control-center`).
* Native clipboard history overlay (`noctalia msg panel-toggle clipboard`).
* Hardware OSD indicators for volume, microphone, and backlight brightness.
* Built-in native C++ telemetry for BlueZ Bluetooth devices and power supplies.

---

## 4. Automated Noctalia Dynamic Theming Architecture

Color management across the desktop environment is fully automated by Noctalia Desktop Shell. Rather than manually editing theme files or maintaining static palette configurations for individual applications, Noctalia operates a built-in and community template processor.

### Dynamic Generation Pipeline
When a palette (such as Catppuccin, Tokyo Night, or wallpaper-derived colors) is selected in Noctalia Settings or triggered via `noctalia msg templates-apply`, Noctalia renders dynamic theme definitions into target application paths:

1. **Hyprland Compositor Borders**:
   Renders `$XDG_CONFIG_HOME/hypr/noctalia.lua`. The native compositor configuration `dotfiles/hypr/hyprland.lua` invokes `require("noctalia").apply_theme()`, instantly applying active and inactive window borders, group titles, and accent colors without restarting Hyprland.

2. **Terminals (Ghostty, Kitty, Foot, tmux)**:
   Renders template palettes for Ghostty, Kitty, Foot, and tmux. Running instances reload colors on the fly via D-Bus notifications and SIGUSR signals.

3. **GTK 3, GTK 4, and Libadwaita Desktop Applications**:
   Renders `$XDG_CONFIG_HOME/gtk-3.0/noctalia.css` and `$XDG_CONFIG_HOME/gtk-4.0/noctalia.css`. Both `dotfiles/gtk-3.0/gtk.css` and `dotfiles/gtk-4.0/gtk.css` import this file directly, providing dynamic `@window_bg_color`, `@accent_color`, and `@headerbar_bg_color` values to all GTK applications, including GNOME Clocks, GNOME Calculator, and Nautilus.
   
   To bypass the static stylesheet caching inherent to GTK4 and Libadwaita, `kkhypr` deploys `libgtk-live-reload.so`. This lightweight shim attaches a user stylesheet provider at priority 810 via `gtk_style_context_add_provider_for_display` and `gtk_style_context_add_provider_for_screen`. It monitors `gtk.css` and `noctalia.css` via inotify file and directory monitors and listens to `GtkSettings::notify::gtk-theme-name`. When palette changes occur, running GTK applications reload styles in under 50 milliseconds without restarting.
   
   Direct GSettings accent color synchronization is enabled for Libadwaita applications by exporting `ADW_DISABLE_PORTAL=1`.

4. **Web Browsers (Google Chrome and Chromium)**:
   Chromium browsers operating under native GTK integration monitor D-Bus changes on `org.gnome.desktop.interface`. Noctalia's [`on-colors-changed.sh`](../dotfiles/noctalia/scripts/on-colors-changed.sh) syncs accent colors and signals browser frames for instant palette alignment.

---

## 5. Background Daemons and Services

### Native Noctalia v5 Desktop Architecture
Noctalia Desktop Shell v5 (rewritten natively in C++) acts as the central desktop environment daemon:
* **Native IPC**: Listens on Wayland and UNIX sockets for `noctalia msg` calls (volume, brightness, screenshots, panels).
* **System Telemetry**: Natively queries BlueZ D-Bus objects for connected peripheral battery states and Linux sysfs for power supply telemetry with zero external polling scripts.
* **Wallpaper Engine**: Built-in GPU-accelerated wallpaper management with transitions (`disc`, `fade`, etc.).

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
