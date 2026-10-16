# kkhypr

[![Platform](https://img.shields.io/badge/Platform-Fedora_44%2B-blue.svg)](https://fedoraproject.org)
[![Compositor](https://img.shields.io/badge/Compositor-Hyprland_0.56%2B-00ADD8.svg)](https://hyprland.org)
[![Config](https://img.shields.io/badge/Config-Native_Lua-000080.svg)](https://www.lua.org)
[![Shell](https://img.shields.io/badge/Shell-Noctalia_v5-purple.svg)](https://noctalia.dev)
[![Terminal](https://img.shields.io/badge/Terminal-Ghostty%20%2F%20Kitty-orange.svg)](https://ghostty.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Reproducible, high-performance, and modular Wayland desktop configuration for Fedora 44+, Hyprland (native Lua configuration), and Noctalia Desktop Shell v5 (native C++ engine). Built on a clean, hardware-agnostic foundation with modular device override hooks.

---

## Architecture and Core Design Decisions

### 1. Hardware-Agnostic Foundation and Device Override Hook
`kkhypr` runs out of the box on any display and GPU architecture (Intel, AMD, NVIDIA, desktop workstations, or laptops). Display output defaults to automatic preferred resolution and scaling.

For systems requiring machine-specific hardware tuning (such as dual-GPU DRM isolation, fixed refresh rates, or custom fractional scaling), `kkhypr` provides an extension hook in `dotfiles/hypr/hyprland.lua`:
```lua
local device_override = os.getenv("HOME") .. "/.config/hypr/device.lua"
local dev_file = io.open(device_override, "r")
if dev_file then
    dev_file:close()
    pcall(dofile, device_override)
end
```
Placing hardware definitions in `~/.config/hypr/device.lua` keeps the core repository completely portable and decoupled from local machine quirks.

### 2. Multi-GPU Zero-Freeze Architecture
To prevent Wayland compositor lockups and 2 to 3 second application startup freezes on hybrid AMD and NVIDIA laptops, Vulkan loaders are constrained to integrated graphics, and discrete GPUs sleep in ACPI D3cold:
```ini
# system/environment.d/10-vulkan-hybrid.conf
VK_LOADER_DRIVERS_SELECT=*radeon*
AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
```

### 3. Native Noctalia Shell v5 C++ Integration
Desktop surfaces, menus, status indicators, and notification popups are driven natively by [Noctalia Desktop Shell v5](https://noctalia.dev) (rewritten in C++). Keybindings interface directly with Noctalia via native IPC (`noctalia msg`):
* **Launcher**: `noctalia msg panel-toggle launcher` (`SUPER + Space`)
* **Control Center**: `noctalia msg panel-toggle control-center` (`SUPER + S`)
* **Settings**: `noctalia msg settings-toggle` (`SUPER + N`)
* **Screenshots**: `noctalia msg screenshot-region` (`SUPER + Print` / `SUPER + Shift + S`)
* **Window Switcher**: `noctalia msg window-switcher hold` (`Alt + Tab`)
* **Volume & Brightness**: Native OSD via `noctalia msg volume-up` / `brightness-up`

### 4. Real-Time Palette Synchronization & GTK Live Reload
All application color palettes are dynamically synchronized by Noctalia:
* [`on-colors-changed.sh`](dotfiles/noctalia/scripts/on-colors-changed.sh) dispatches active palette updates to GTK 3/4, Chromium, KDE 6 applications (Dolphin via native D-Bus signals), and btop with file locking (`flock`) to prevent race conditions.
* Real-time GTK stylesheet hot-reloading is achieved via [`libgtk-live-reload.c`](dotfiles/gtk/libgtk-live-reload.c).

### 5. Separation of Concerns: Desktop vs Developer Tooling
`kkhypr` focuses strictly on the Wayland desktop environment, compositor, shell, and terminal layers. Developer toolchains, code editors (Neovim, VS Code, Zed), and AI agent skills are maintained in the companion repository [dev-suite](https://github.com/kk376/dev-suite).

---

## Desktop Stack

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Compositor** | Hyprland 0.56+ | Wayland compositor configured with native Lua (`hyprland.lua`) |
| **Desktop Shell** | Noctalia Shell v5 (C++) | Top bar, launcher, quick settings, notifications, OSD, lockscreen |
| **Terminals** | Ghostty, Kitty, Foot | Native GPU-accelerated Wayland terminal emulators |
| **Multiplexer** | tmux | Terminal session multiplexing with Noctalia palette integration |
| **System Monitor** | btop | Terminal resource monitor with live SIGUSR2 palette reload |
| **Audio Server** | PipeWire / WirePlumber | Audio routing and Bluetooth policy (`50-bluez.conf`) |
| **Styling** | GTK 3 & GTK 4 | High-contrast selection rules and dynamic Noctalia CSS |

---

## Repository Structure

```text
kkhypr/
├── .gitignore
├── LICENSE                   # MIT License
├── Makefile                  # Lifecycle targets: lint, check, dry-run, install, status
├── README.md                 # Primary system documentation
├── docs/                     # Architectural guides
│   ├── ARCHITECTURE.md       # Deep-dive system design and daemon architecture
│   ├── HARDWARE_DRM.md       # Multi-GPU routing and D3cold power verification
│   ├── KEYBINDINGS.md        # Canonical shortcuts reference card
│   ├── flatpak-terminal-flicker.md # Flatpak terminal rendering notes
│   └── hyprland-vrr.md       # Variable Refresh Rate (VRR) documentation
├── dotfiles/
│   ├── btop/
│   │   └── btop.conf         # System monitor configuration
│   ├── foot/
│   │   └── foot.ini          # Lightweight terminal configuration
│   ├── ghostty/
│   │   ├── config.ghostty    # Ghostty GPU terminal configuration
│   │   ├── gtk.css           # GTK4 tab styling
│   │   └── themes/noctalia   # Noctalia palette theme
│   ├── gtk/
│   │   └── libgtk-live-reload.c # GTK live stylesheet reload shim source
│   ├── gtk-3.0/              # GTK3 styling and high-contrast selection
│   │   ├── gtk.css
│   │   ├── gtk-dark.css
│   │   ├── noctalia.css
│   │   └── settings.ini
│   ├── gtk-4.0/              # GTK4 styling and high-contrast selection
│   │   ├── gtk.css
│   │   ├── gtk-dark.css
│   │   ├── noctalia.css
│   │   └── settings.ini
│   ├── hypr/
│   │   ├── hyprland.lua      # Master native Lua Hyprland configuration
│   │   ├── hyprtoolkit.conf  # UI toolkit configuration
│   │   └── noctalia.lua      # Noctalia border sync helper
│   ├── kitty/
│   │   └── kitty.conf        # Kitty GPU terminal configuration
│   ├── noctalia/
│   │   ├── config.toml       # Streamlined Noctalia v5 shell configuration
│   │   └── scripts/
│   │       └── on-colors-changed.sh # Master color synchronization hook
│   ├── systemd/
│   │   └── user/             # Session targets and systemd drop-ins
│   ├── tmux/
│   │   ├── tmux.conf         # tmux multiplexer configuration
│   │   └── themes/           # tmux Noctalia theme
│   └── wireplumber/
│       └── wireplumber.conf.d/
│           └── 50-bluez.conf # WirePlumber Bluetooth audio codec policy
├── system/
│   └── environment.d/
│       └── 10-vulkan-hybrid.conf # Multi-GPU isolation environment drop-in
└── install.sh                # Automated, idempotent deployment script
```

---

## Installation and Deployment

### 1. Prerequisites (Fedora 44+)

Install required packages from Fedora repositories and Copr:

```bash
# Enable official Hyprland and Ghostty Copr repositories
sudo dnf copr enable -y lionheartp/Hyprland && sudo dnf copr enable -y scottames/ghostty

# Install core packages
sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprpolkitagent hyprland-guiutils \
    noctalia brightnessctl pipewire-utils grim slurp wl-clipboard ghostty
```

### 2. Validate Configurations

Run static analysis and configuration checks before deploying:

```bash
make lint
```

### 3. Deploy Symlinks

Simulate the deployment:

```bash
make dry-run
```

Apply the symlinks to `~/.config/`:

```bash
make install
```

To deploy optional hybrid GPU environment rules:

```bash
./install.sh --hybrid-gpu
```

Any pre-existing non-symlink configuration is safely backed up with a timestamped suffix (`.backup.YYYYMMDD_HHMMSS`).

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
