# kkhypr

Reproducible, zero-freeze Wayland desktop configuration for Fedora 44+, Hyprland 0.56+, Noctalia Shell v5, Ghostty, and GDM.

Target hardware: AMD Ryzen 5 7535HS (Radeon 680M primary iGPU) paired with an NVIDIA GeForce RTX 2050 Mobile (dGPU).

---

## Architecture and Core Design Decisions

### 1. Dual-GPU Zero-Freeze DRM Routing
Linux kernel DRM assignment on hybrid laptops frequently maps `/dev/dri/card0` to the discrete NVIDIA controller and `/dev/dri/card1` to the integrated AMD processor. Under standard Wayland compositors, launching desktop applications triggers Vulkan ICD discovery across all device nodes. This wakes the sleeping NVIDIA dGPU from ACPI D3cold power state, causing severe 2 to 3 second micro-freezes.

`kkhypr` eliminates these freezes through two deterministic environment rules:

1. **Explicit DRM Card Ordering**:
   `AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0`
   Binds the Aquamarine compositor backend directly to the integrated AMD Radeon 680M (`card1`). The NVIDIA card (`card0`) remains secondary and stays powered down in D3cold. Note that Aquamarine uses colon delimiters, so PCI by-path identifiers containing colons must be avoided.

2. **Vulkan ICD Loader Filtration**:
   `VK_LOADER_DRIVERS_SELECT=*radeon*`
   Restricts Vulkan driver initialization to the Radeon Mesa driver. GTK4 and Libadwaita applications (such as Nautilus) launch instantly without probing the NVIDIA driver.

### 2. Desktop Components
* **Compositor**: [Hyprland 0.56](https://hyprland.org) via Copr `lionheartp/Hyprland` (configured via native Lua)
* **Shell and Widgets**: [Noctalia Desktop Shell v5](https://noctalia.dev) (top bar, launcher, quick settings, notifications, OSD)
* **Terminal Emulator**: [Ghostty](https://ghostty.org) (native GTK4/Wayland, zero weak-dependency bloat)
* **Idle Daemon**: `hypridle` (dimming, session locking, DPMS off, and suspend)
* **Screen Locker**: `hyprlock` (hardware-accelerated blurred backdrop and PAM authentication)
* **Wallpaper Engine**: `hyprpaper`
* **Display Manager**: GDM (GNOME Display Manager) with Wayland session support

---

## Repository Structure

```text
kkhypr/
├── dotfiles/
│   ├── hypr/
│   │   ├── hyprland.lua      # Hyprland 0.56+ native Lua configuration
│   │   ├── hyprland.conf     # Legacy configuration fallback
│   │   ├── hypridle.conf     # Idle and power management daemon
│   │   ├── hyprlock.conf     # Lockscreen configuration
│   │   └── hyprpaper.conf    # Wallpaper daemon configuration
│   └── noctalia/
│       └── config.toml       # Noctalia Shell v5 layout and widget config
├── system/
│   └── environment.d/
│       └── 10-vulkan-hybrid.conf # Systemd user environment GPU rules
├── install.sh                # Automated, idempotent symlink deployment script
├── Makefile                  # Build, lint, check, and status targets
└── README.md
```

---

## Installation and Deployment

### 1. Prerequisites (Fedora 44+)

Install the required packages from Fedora repositories and the Hyprland Copr:

```bash
# Enable the recommended Fedora 44 Hyprland Copr
sudo dnf copr enable -y lionheartp/Hyprland

# Install core packages
sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprpolkitagent \
    hyprpaper hypridle hyprlock noctalia \
    brightnessctl pipewire-utils grim slurp wl-clipboard

# Remove unwanted terminal dependencies if pulled as weak recommendations
sudo dnf remove -y kitty kitty-kitten kitty-shell-integration kitty-terminfo
```

### 2. Validate Configurations

Run static analysis and compositor verification before deploying:

```bash
make lint
```

This target runs:
* `shellcheck install.sh`
* `hyprland --verify-config -c dotfiles/hypr/hyprland.lua`
* `hyprland --verify-config -c dotfiles/hypr/hyprland.conf`
* `noctalia config validate dotfiles/noctalia/config.toml`

### 3. Deploy Symlinks

Simulate the deployment first:

```bash
make dry-run
```

Apply the symlinks to `~/.config/`:

```bash
make install
```

The script links:
* `dotfiles/hypr/*` -> `~/.config/hypr/*` (including `hyprland.lua`)
* `dotfiles/noctalia/config.toml` -> `~/.config/noctalia/config.toml`
* `system/environment.d/10-vulkan-hybrid.conf` -> `~/.config/environment.d/10-vulkan-hybrid.conf`

Any pre-existing non-symlink configuration is safely backed up with a timestamped suffix (`.backup.YYYYMMDD_HHMMSS`).

---

## Keybindings Reference

The primary modifier key is `SUPER` (Windows key).

### Applications
| Keybinding | Action | Command |
| :--- | :--- | :--- |
| `SUPER + Enter` | Launch Terminal | `ghostty` |
| `SUPER + Space` | Toggle App Launcher | `noctalia msg launcher:toggle` |
| `SUPER + E` | File Manager | `nautilus` |
| `SUPER + B` | Web Browser | `google-chrome` |
| `SUPER + L` | Lock Screen | `loginctl lock-session` |

### Window Management
| Keybinding | Action |
| :--- | :--- |
| `SUPER + Q` | Close active window (`killactive`) |
| `SUPER + V` | Toggle floating mode (`togglefloating`) |
| `SUPER + F` | Toggle fullscreen (`fullscreen, 0`) |
| `SUPER + P` | Toggle pseudotile mode (`pseudo`) |
| `SUPER + J` | Toggle layout split direction (`layoutmsg, togglesplit`) |
| `SUPER + M` | Exit Hyprland session |

### Navigation and Workspaces
| Keybinding | Action |
| :--- | :--- |
| `SUPER + [H/J/K/L]` or Arrows | Focus window in direction (left, down, up, right) |
| `SUPER + Shift + Arrows` | Move active window in direction |
| `SUPER + [1-0]` | Switch to workspace 1 through 10 |
| `SUPER + Shift + [1-0]` | Move active window to workspace 1 through 10 |
| `SUPER + Left Mouse Drag` | Move floating window |
| `SUPER + Right Mouse Drag` | Resize floating window |

### Media, Brightness, and Screenshots
| Keybinding | Action |
| :--- | :--- |
| `XF86AudioRaiseVolume` | Volume up 5% (`wpctl`) |
| `XF86AudioLowerVolume` | Volume down 5% (`wpctl`) |
| `XF86AudioMute` | Mute toggle (`wpctl`) |
| `XF86MonBrightnessUp` | Screen brightness up 5% (`brightnessctl`) |
| `XF86MonBrightnessDown` | Screen brightness down 5% (`brightnessctl`) |
| `Print` | Interactive area screenshot saved to `~/Pictures/Screenshots/` and clipboard |
| `SUPER + Shift + S` | Interactive area screenshot copied directly to clipboard |

---

## Display Manager (GDM) Setup

GDM (GNOME Display Manager) is the official and recommended display manager for `kkhypr`. It coordinates Plymouth boot-splash handoff cleanly without DRM master lock contention and launches Hyprland reliably:

```bash
sudo systemctl enable --now gdm
```

Select **Hyprland** from the session gear menu on the GDM login screen.

---

## Power and GPU Verification

To verify that the NVIDIA GPU is sleeping in D3cold while operating Hyprland:

```bash
make status
```

Or query the kernel sysfs directly:

```bash
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
```

Expected output during normal desktop usage: `suspended`.
