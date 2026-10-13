# kkhypr

[![Platform](https://img.shields.io/badge/Platform-Fedora_44%2B-blue.svg)](https://fedoraproject.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland_0.56%2B-00ADD8.svg)](https://hyprland.org)
[![Config](https://img.shields.io/badge/Config-Native_Lua-000080.svg)](https://www.lua.org)
[![Shell](https://img.shields.io/badge/Shell-Noctalia_v5-purple.svg)](https://noctalia.dev)
[![Terminal](https://img.shields.io/badge/Terminal-Ghostty-orange.svg)](https://ghostty.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Reproducible, high-performance, and modular Wayland desktop configuration for Fedora 44+, Hyprland 0.56+, Noctalia Desktop Shell v5, Ghostty, and GDM. Built on a universal, hardware-agnostic foundation with automatic chassis detection and modular application gating.

---

## Architecture and Core Design Decisions

### 1. Universal Hardware Foundation and Device Override Extension Hook
`kkhypr` runs out of the box on any display and GPU architecture (Intel, AMD, NVIDIA, desktop workstations, or laptops). Display output defaults to automatic preferred resolution and scaling.

For systems requiring machine-specific hardware tuning (such as dual-GPU DRM isolation, fixed 144Hz refresh rates, or custom fractional scaling), `kkhypr` provides an extension hook in `dotfiles/hypr/hyprland.lua`:
```lua
local device_override = os.getenv("HOME") .. "/.config/hypr/device.lua"
local dev_file = io.open(device_override, "r")
if dev_file then
    dev_file:close()
    pcall(dofile, device_override)
end
```
Placing hardware definitions in `~/.config/hypr/device.lua` keeps the core repository completely portable and decoupled from local machine quirks.

### 2. Chassis-Aware Power Management (Laptop vs Desktop)
The deployment engine inspects the system chassis via `hostnamectl`, `/sys/class/dmi/id/chassis_type`, and internal battery subsystems:
* **Laptops**: Configures `hypridle` with 2.5 minute backlight dimming via `brightnessctl` and enables hardware brightness hotkeys.
* **Desktops**: Configures `hypridle` with DPMS screen-off and session lock timeouts while omitting laptop backlight dimmers that fail on desktop external displays.

### 3. Modular Application Gating
Dotfiles are deployed dynamically based on installed software. If an application (such as Zed, VS Code, VSCodium, Neovim, or btop) is not installed on the system, its configuration directory is cleanly skipped during installation, preventing configuration bloat. Passing `--all` deploys all application templates regardless of current installation status.

### 4. Pure Public Distribution
All personal artificial intelligence model defaults (such as Ollama and Qwen) and hardcoded user home directories have been purged from the base configuration. The repository is 100% plug-and-play for any user.

### 5. Native Lua Configuration Engine
Hyprland 0.56 introduces native Lua configuration support. `kkhypr` defines the entire compositor surface cleanly in `dotfiles/hypr/hyprland.lua`, using structured tables, loops, and callbacks to provide a modular and type-safe environment.

### 6. Noctalia Desktop Shell v5 & Luau Plugins
Desktop surfaces, menus, status indicators, and notification popups are driven by [Noctalia Desktop Shell v5](https://noctalia.dev). Custom Luau plugins in `dotfiles/noctalia/plugins/custom_bar/` provide:
* Vertical cell battery status glyphs with direct power-supply sysfs telemetry.
* Live Bluetooth peripheral connection and battery percentage monitoring via D-Bus.

The optional third-party [Wallpaper Carousel](https://github.com/motor-dev/wallpaperCarousel) plugin can be installed under Noctalia's local data directory. Its install, activation, wallpaper folder setup, and `SUPER + W` binding are documented in [docs/NOCTALIA_WALLPAPER_CAROUSEL.md](docs/NOCTALIA_WALLPAPER_CAROUSEL.md).

### 7. Dynamic Workspace Compaction
In standard tiling environments, closing windows can leave orphaned or fragmented desktop numbers. The bundled compactor daemon (`dotfiles/hypr/scripts/compact_workspaces.py`) listens to Hyprland socket events and dynamically collapses open workspaces into a contiguous sequence.

### 8. Automated Noctalia Dynamic Theming and Frosted Glassmorphism
All application color palettes are dynamically driven by Noctalia Desktop Shell. When a palette (such as Catppuccin, Tokyo Night, or wallpaper-derived tones) is selected in Noctalia Settings or updated via the CLI, Noctalia's template processor synchronizes the color scheme across Ghostty, GTK3/4, Hyprland borders, Zed, VS Code, and VSCodium automatically. Manual palette files and hardcoded color overrides are eliminated. Window opacity and blur across editors and terminals are managed through Hyprland window rules and ignore_opacity blur passes, delivering a frosted glass aesthetic while letting Noctalia manage all colors.

### 9. Dual Appearance Profiles and Dynamic Opacity
Centralized profile management via `scripts/hypr-profile.sh` allows switching between two distinct aesthetic modes on the fly:
* **Default**: 100% solid, fully opaque surfaces with compositor blur disabled for maximum performance and contrast.
* **Blur**: Glassmorphism with compositor Kawase blur passes and dynamic opacity (defaulting to `0.95`, or any custom `0.x` value) applied synchronously across Ghostty, Noctalia top bar and dock, Hyprland windows, and Neovim transparency.

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
| GUI Dialogs | `hyprland-guiutils` | Runtime system dialogs, error banners, and prompts |
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
│   ├── HARDWARE_DRM.md       # Multi-GPU routing and D3cold power verification (optional)
│   ├── KEYBINDINGS.md        # Canonical shortcuts reference card
│   ├── NOCTALIA_WALLPAPER_CAROUSEL.md # Optional Noctalia wallpaper carousel plugin setup
│   ├── flatpak-terminal-flicker.md # Flatpak terminal rendering notes
│   └── hyprland-vrr.md       # Variable Refresh Rate (VRR) documentation
├── dotfiles/
│   ├── btop/
│   │   └── btop.conf         # System monitor configuration
│   ├── ghostty/
│   │   ├── config.ghostty    # Ghostty terminal configuration
│   │   ├── gtk.css           # GTK4 tab styling and matching bar opacity
│   │   ├── scripts/          # Ghostty theme synchronizers
│   │   └── themes/
│   │       └── noctalia      # Dynamic theme generated by Noctalia
│   ├── gtk/
│   │   └── libgtk-live-reload.c # GTK live stylesheet reload helper
│   ├── gtk-3.0/              # GTK3 styling importing dynamic noctalia.css
│   │   ├── gtk.css
│   │   ├── gtk-dark.css
│   │   ├── noctalia.css      # Generated by Noctalia template engine
│   │   └── settings.ini
│   ├── gtk-4.0/              # GTK4 styling importing dynamic noctalia.css
│   │   ├── gtk.css
│   │   ├── gtk-dark.css
│   │   ├── noctalia.css      # Generated by Noctalia template engine
│   │   └── settings.ini
│   ├── hypr/
│   │   ├── hyprland.lua      # Modern native Lua configuration
│   │   ├── hypridle.conf     # Idle and suspend daemon configuration
│   │   ├── hyprlock.conf     # Hardware-accelerated lockscreen configuration
│   │   ├── hyprpaper.conf    # Wallpaper daemon configuration
│   │   ├── noctalia.lua      # Dynamic Hyprland borders generated by Noctalia
│   │   └── scripts/
│   │       ├── app_menu.sh           # Active app context menu
│   │       ├── bt_battery_sync.py    # D-Bus Bluetooth battery daemon
│   │       ├── compact_workspaces.py # Dynamic workspace compactor
│   │       ├── exit.sh               # Graceful session exit handler
│   │       ├── screenshot.sh         # 3-tier screenshot script (grim/slurp)
│   │       └── session_teardown_listener.py # Session teardown cleanup daemon
│   ├── noctalia/
│   │   ├── config.toml       # Noctalia Shell v5 layout and template config
│   │   ├── colors.json       # Generated color palette definition
│   │   ├── palettes/         # Custom palette catalog
│   │   ├── plugins/          # Custom Luau status bar plugins
│   │   │   └── custom_bar/   # Bluetooth and battery telemetry widgets
│   │   └── scripts/
│   │       ├── sync-gtk-theme.sh     # Dynamic GTK theme sync hook
│   │       └── toggle-emoji.sh       # Emoji picker toggle action
│   ├── nvim/                 # Neovim configuration with dynamic base16 & transparency
│   │   ├── init.lua
│   │   ├── lazy-lock.json
│   │   └── lua/
│   │       ├── config/       # Options, keymaps, autocmds (transparency)
│   │       └── plugins/      # Base16, colorscheme, and treesitter
│   ├── systemd/
│   │   └── user/             # Systemd user services and session targets
│   ├── vscode/               # VS Code configuration using NoctaliaTheme
│   │   └── settings.json
│   ├── vscodium/             # VSCodium configuration using NoctaliaTheme
│   │   └── settings.json
│   ├── wireplumber/
│   │   └── wireplumber.conf.d/
│   │       └── 50-bluez.conf # WirePlumber audio and Bluetooth policy
│   └── zed/                  # Zed Editor configuration using Noctalia Dark/Light
│       ├── settings.json
│       ├── keymap.json
│       ├── tasks.json
│       └── themes/
│           └── noctalia.json # Dynamic theme generated by Noctalia
├── install.sh                # Automated, idempotent deployment script
├── presets/                  # Preconfigured system appearance profiles
│   ├── blur/                 # Frosted glass profile (opacity 0.95, blur enabled)
│   │   ├── btop/btop.conf
│   │   ├── ghostty/config.ghostty
│   │   ├── ghostty/gtk.css
│   │   ├── hypr/hyprland.lua
│   │   └── noctalia/config.toml
│   └── default/              # Solid opaque profile (opacity 1.0, blur disabled)
│       ├── btop/btop.conf
│       ├── ghostty/config.ghostty
│       ├── ghostty/gtk.css
│       ├── hypr/hyprland.lua
│       └── noctalia/config.toml
├── scripts/                  # Profile switcher and user helpers
│   └── hypr-profile.sh       # Dynamic opacity switcher (default/blur [0.x])
└── system/                   # Optional system-level drop-ins
    ├── environment.d/        # Hardware/session environment drop-ins
    └── systemd/              # Optional systemd drop-ins
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
| `SUPER + W` | Wallpaper Carousel | `noctalia msg plugin yngwe/wallpaperCarousel:service all toggle` |
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
# Enable the official Fedora 44 Hyprland and Ghostty copr
sudo dnf copr enable -y lionheartp/Hyprland && sudo dnf copr enable -y scottames/ghostty

# Install core packages
sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprpolkitagent hyprland-guiutils \
    hyprpaper hypridle hyprlock noctalia \
    brightnessctl pipewire-utils grim slurp quickshell wl-clipboard ghostty

```

### 2. Validate Configurations

Run static analysis and compositor verification before deploying:

```bash
make lint
```

This target runs:
* `shellcheck install.sh`
* `hyprland --verify-config -c dotfiles/hypr/hyprland.lua`
* `noctalia config validate dotfiles/noctalia/config.toml`

### 3. Deploy Symlinks

Simulate the deployment:

```bash
make dry-run
```

Apply the symlinks to `~/.config/`:

```bash
make install
```

The installer dynamically detects your system chassis (laptop vs desktop) and inspects installed applications:
* Links core Hyprland, Noctalia shell, GTK 3/4 styling, and systemd session targets.
* Adapts `hypridle.conf` based on chassis type (enabling backlight dimming for laptops, DPMS power management for desktops).
* Configures Ghostty, Neovim, Zed, VS Code, VSCodium, btop, and WirePlumber if their respective binaries are detected on your PATH.

To deploy all dotfiles regardless of currently installed packages:

```bash
./install.sh --all
```

Any pre-existing non-symlink configuration is safely backed up with a timestamped suffix (`.backup.YYYYMMDD_HHMMSS`).

Wallpaper Carousel is an optional third-party Noctalia plugin and is installed separately from the dotfiles. Follow [docs/NOCTALIA_WALLPAPER_CAROUSEL.md](docs/NOCTALIA_WALLPAPER_CAROUSEL.md) to install and enable it; the `SUPER + W` binding is included in the Hyprland configuration and both appearance presets.

---

## Appearance Profiles and Dynamic Opacity

`kkhypr` provides a centralized profile engine (`scripts/hypr-profile.sh`) allowing you to switch between a solid opaque aesthetic and translucent glassmorphism with blur across Hyprland, Noctalia, Ghostty, and editors:

### Presets

* **Default (`hypr-default`)**: 100% solid, fully opaque surfaces without compositor blur.
* **Blur (`hypr-blur [0.x]`)**: Glassmorphism with compositor Kawase blur passes and adjustable opacity (default `0.95`, or custom `0.x`).

### Usage

```bash
# Switch to solid opaque theme (opacity 1.0, blur disabled)
hypr-default

# Switch to frosted glass theme (default opacity 0.95, blur enabled)
hypr-blur

# Set custom opacity dynamically (e.g. 0.90 across Ghostty, Noctalia, and Hyprland)
hypr-blur 0.90
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
