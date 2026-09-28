# kkhypr

[![Platform](https://img.shields.io/badge/Platform-Fedora_44%2B-blue.svg)](https://fedoraproject.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland_0.56%2B-00ADD8.svg)](https://hyprland.org)
[![Config](https://img.shields.io/badge/Config-Native_Lua-000080.svg)](https://www.lua.org)
[![Shell](https://img.shields.io/badge/Shell-Noctalia_v5-purple.svg)](https://noctalia.dev)
[![Terminal](https://img.shields.io/badge/Terminal-Ghostty-orange.svg)](https://ghostty.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Reproducible, zero-freeze Wayland desktop configuration for Fedora 44+, Hyprland 0.56+, Noctalia Desktop Shell v5, Ghostty, and GDM.

Target hardware reference: AMD Ryzen 5 7535HS (Radeon 680M primary iGPU) paired with NVIDIA GeForce RTX 2050 Mobile (dGPU).

---

## Architecture and Core Design Decisions

### 1. Dual-GPU Zero-Freeze DRM Routing
Linux kernel DRM assignment on hybrid laptops frequently maps `/dev/dri/card0` to the discrete NVIDIA controller and `/dev/dri/card1` to the integrated AMD processor. Under standard Wayland compositors, launching desktop applications triggers Vulkan ICD discovery across all device nodes. This wakes the sleeping NVIDIA dGPU from ACPI D3cold power state, causing severe 2 to 3 second micro-freezes and rapid battery consumption.

`kkhypr` eliminates these freezes through two deterministic environment rules:

1. **Explicit DRM Card Ordering**:
   `AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0`
   Binds the Aquamarine compositor backend directly to the integrated AMD Radeon 680M (`card1`). The NVIDIA card (`card0`) remains secondary and stays powered down in D3cold. Note that Aquamarine uses colon delimiters, so PCI by-path identifiers containing colons must not be used.

2. **Vulkan ICD Loader Filtration**:
   `VK_LOADER_DRIVERS_SELECT=*radeon*`
   Restricts Vulkan driver initialization to the Radeon Mesa driver. GTK4 and Libadwaita applications (such as Nautilus) launch instantly without probing the NVIDIA driver.

Read the complete guide in [docs/HARDWARE_DRM.md](docs/HARDWARE_DRM.md).

### 2. Native Lua Configuration Engine
Hyprland 0.56 introduces native Lua configuration support. `kkhypr` defines the entire compositor surface in `dotfiles/hypr/hyprland.lua`, using structured tables, loops, and callbacks while maintaining a fully validated `dotfiles/hypr/hyprland.conf` legacy fallback.

### 3. Noctalia Desktop Shell v5 & Luau Plugins
Desktop surfaces, menus, status indicators, and notification popups are driven by [Noctalia Desktop Shell v5](https://noctalia.dev). Custom Luau plugins in `dotfiles/noctalia/plugins/custom_bar/` provide:
* Vertical cell battery status glyphs with direct power-supply sysfs telemetry.
* Live Bluetooth peripheral connection and battery percentage monitoring via D-Bus.

### 4. Dynamic Workspace Compaction
In standard tiling environments, closing windows can leave orphaned or fragmented desktop numbers. The bundled compactor daemon (`dotfiles/hypr/scripts/compact_workspaces.py`) listens to Hyprland socket events and dynamically collapses open workspaces into a contiguous sequence.

### 5. Ghostty Terminal Dynamic Palette Synchronization
`kkhypr` integrates Ghostty with Noctalia's built-in template engine. When changing desktop wallpapers or switching theme palettes, Noctalia automatically renders dynamic color schemes into `~/.config/ghostty/themes/noctalia`, sets `theme = noctalia` in `config.ghostty`, and signals running Ghostty instances via GTK D-Bus and `SIGUSR2` for instant live reload.

---

## Desktop Stack

| Component | Technology | Role |
| :--- | :--- | :--- |
| Compositor | Hyprland 0.56+ (via Copr `lionheartp/Hyprland`) | Wayland compositor configured with native Lua |
| Desktop Shell | Noctalia Shell v5 | Top bar, launcher, quick settings, notifications, OSD |
| Terminal | Ghostty | Native GPU-accelerated Wayland terminal emulator |
| Display Manager | GDM (GNOME Display Manager) | Plymouth handoff and session launching |
| Idle Daemon | `hypridle` | Screen dimming, session locking, and system suspend |
| Screen Locker | `hyprlock` | Blurred backdrop lockscreen with PAM authentication |
| Wallpaper | `hyprpaper` | Smooth wallpaper transitions |
| Audio Server | PipeWire / WirePlumber | Audio routing and `wpctl` volume control |

---

## Repository Structure

```text
kkhypr/
├── .gitignore
├── LICENSE                   # MIT License
├── Makefile                  # Lifecycle targets: lint, check, dry-run, install, status
├── README.md                 # Primary system documentation
├── docs/                     # Specialized architectural guides
│   ├── ARCHITECTURE.md       # Deep-dive system design and daemon architecture
│   ├── HARDWARE_DRM.md       # Multi-GPU routing and D3cold power verification
│   └── KEYBINDINGS.md        # Canonical shortcuts reference card
├── dotfiles/
│   ├── hypr/
│   │   ├── hyprland.lua      # Modern native Lua configuration
│   │   ├── hyprland.conf     # Legacy configuration fallback
│   │   ├── hypridle.conf     # Idle and suspend daemon configuration
│   │   ├── hyprlock.conf     # Hardware-accelerated lockscreen configuration
│   │   ├── hyprpaper.conf    # Wallpaper daemon configuration
│   │   └── scripts/
│   │       ├── app_menu.sh           # Active app context menu
│   │       ├── bt_battery_sync.py    # D-Bus Bluetooth battery daemon
│   │       ├── compact_workspaces.py # Dynamic workspace compactor
│   │       └── screenshot.sh         # 3-tier screenshot script (grim/slurp)
│   ├── ghostty/
│   │   ├── config.ghostty    # Ghostty terminal configuration
│   │   └── gtk.css           # GTK4 tab bar and toolbar styling
│   ├── noctalia/
│   │   ├── config.toml       # Noctalia Shell v5 layout and template config
│   │   └── plugins/          # Custom Luau status bar plugins
│   └── systemd/
│       └── user/             # Systemd user services and session targets
├── install.sh                # Automated, idempotent deployment script
└── system/
    └── environment.d/
        └── 10-vulkan-hybrid.conf # Systemd user environment GPU rules
```

---

## Keybindings Quick Reference

The primary modifier key is `SUPER` (Windows key). See [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) for the complete reference.

### Applications
| Keybinding | Action | Command |
| :--- | :--- | :--- |
| `SUPER + Return` | Terminal | `ghostty` |
| `SUPER + T` | Terminal (Alternative) | `ghostty` |
| `SUPER + Space` | Application Launcher | `noctalia msg panel-toggle launcher` |
| `SUPER + E` | File Manager | `nautilus` |
| `SUPER + C` | VS Code | `code` |
| `SUPER + Z` | Zed Editor | `~/.local/bin/zed` |
| `SUPER + B` | Web Browser | `google-chrome` |
| `SUPER + N` | Control Center | `noctalia msg panel-toggle control-center` |
| `SUPER + SHIFT + C` | Clipboard History | `noctalia msg panel-toggle clipboard` |
| `SUPER + Escape` | Lock Screen | `loginctl lock-session` |

### Window Management
| Keybinding | Action |
| :--- | :--- |
| `SUPER + Q` | Close active window (`killactive`) |
| `SUPER + V` | Toggle floating mode (`togglefloating`) |
| `SUPER + F` or `F11` | Toggle fullscreen mode (`fullscreen, 0`) |
| `SUPER + P` | Toggle pseudotile mode (`pseudo`) |
| `SUPER + S` | Toggle layout split direction (`layoutmsg, togglesplit`) |
| `SUPER + SHIFT + M` | Exit Hyprland session |

### Navigation and Movement
| Keybinding | Action |
| :--- | :--- |
| `SUPER + [H/J/K/L]` or Arrows | Focus window in direction (left, down, up, right) |
| `SUPER + SHIFT + [H/J/K/L]` or Arrows | Move active window in direction |
| `SUPER + [1-0]` | Switch to workspace 1 through 10 |
| `SUPER + SHIFT + [1-0]` | Move active window to workspace 1 through 10 |
| `SUPER + Left Mouse Drag` | Move floating window |
| `SUPER + Right Mouse Drag` | Resize floating window |

### Media and Screenshots
| Keybinding | Action |
| :--- | :--- |
| `Print` | Interactive area screenshot saved and copied to clipboard |
| `SUPER + Print` | Full active display screenshot |
| `XF86AudioRaiseVolume` / `Lower` | Volume up or down by 5% (`wpctl`) |
| `XF86AudioMute` | Toggle audio mute (`wpctl`) |
| `XF86MonBrightnessUp` / `Down` | Display brightness up or down by 5% (`brightnessctl`) |

---

## Installation and Deployment

### 1. Prerequisites (Fedora 44+)

Install required packages from Fedora repositories and the Hyprland Copr:

```bash
# Enable the official Fedora 44 Hyprland Copr
sudo dnf copr enable -y lionheartp/Hyprland

# Install core packages
sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprpolkitagent \
    hyprpaper hypridle hyprlock noctalia \
    brightnessctl pipewire-utils grim slurp wl-clipboard

# Remove unwanted terminal dependencies if pulled as weak recommendations
sudo dnf remove -y kitty kitty-kitten kitty-shell-integration kitty-terminfo
```

### 2. Disable Redundant Fedora Background Services (Reclaims ~246 MB RAM)

Fedora Workstation enables background services that are redundant for a lightweight tiling desktop environment. Disabling them frees approximately 246 MB of idle RAM:

* **ABRT (Automatic Bug Reporting Tool)**: Four background daemons (`abrtd`, `abrt-journal-core`, `abrt-oops`, `abrt-xorg`) consume ~190 MB RAM waiting to collect core dumps for Red Hat Bugzilla.
* **Rsyslog**: Legacy syslog daemon consuming ~56 MB RAM, redundant because `systemd-journald` captures, indexes, and retains all system logs natively.

Disable both services immediately:

```bash
# Disable ABRT crash reporting daemons (~190 MB idle RAM)
sudo systemctl disable --now abrtd.service abrt-journal-core.service abrt-oops.service abrt-xorg.service

# Disable legacy rsyslog daemon (~56 MB idle RAM)
sudo systemctl disable --now rsyslog.service
```

Alternatively, run the Makefile target:

```bash
make optimize-services
```

Or pass `--optimize-services` during deployment:

```bash
./install.sh --optimize-services
```

### 3. Validate Configurations

Run static analysis and compositor verification before deploying:

```bash
make lint
```

This target runs:
* `shellcheck install.sh`
* `hyprland --verify-config -c dotfiles/hypr/hyprland.lua`
* `hyprland --verify-config -c dotfiles/hypr/hyprland.conf`
* `noctalia config validate dotfiles/noctalia/config.toml`

### 4. Deploy Symlinks

Simulate the deployment:

```bash
make dry-run
```

Apply the symlinks to `~/.config/`:

```bash
make install
```

The script links:
* `dotfiles/hypr/*` -> `~/.config/hypr/*`
* `dotfiles/noctalia/config.toml` -> `~/.config/noctalia/config.toml`
* `dotfiles/noctalia/plugins` -> `~/.config/noctalia/plugins`
* `dotfiles/systemd/user/*` -> `~/.config/systemd/user/*`
* `system/environment.d/10-vulkan-hybrid.conf` -> `~/.config/environment.d/10-vulkan-hybrid.conf`

Any pre-existing non-symlink configuration is safely backed up with a timestamped suffix (`.backup.YYYYMMDD_HHMMSS`).

---

## Display Manager (GDM) Setup

GDM (GNOME Display Manager) is the standard display manager for `kkhypr`. It coordinates Plymouth boot-splash handoff cleanly without DRM master lock contention and launches Hyprland reliably:

```bash
sudo systemctl enable --now gdm
```

Select **Hyprland** from the session gear menu on the GDM login screen.

---

## Power and GPU Verification

To verify that the NVIDIA dGPU is sleeping in D3cold while operating Hyprland:

```bash
make status
```

Or query the kernel sysfs directly:

```bash
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
```

Expected output during normal desktop usage: `suspended`.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
