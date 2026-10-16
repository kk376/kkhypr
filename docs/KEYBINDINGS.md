# Keybindings Reference

This document provides the canonical keybinding reference for `kkhypr`.

The primary modifier key is `SUPER` (the Windows or Command key). All navigation, window management, and workspace transfers follow ergonomic Vim and directional conventions.

---

## 1. Application Launchers

| Keybinding | Target | Description | Executed Command |
| :--- | :--- | :--- | :--- |
| `SUPER + Return` | Terminal | Launch Ghostty GPU-accelerated terminal emulator | `ghostty` |
| `SUPER + T` | Terminal | Alternative terminal shortcut | `ghostty` |
| `SUPER + Space` | Application Launcher | Toggle Noctalia search and application launcher | `noctalia msg panel-toggle launcher` |
| `SUPER + E` | File Manager | Launch GNOME Nautilus file manager | `nautilus` |
| `SUPER + C` | VS Code | Launch Visual Studio Code editor | `code` |
| `SUPER + Z` | Zed Editor | Launch high-performance native Zed editor | `~/.local/bin/zed` |
| `SUPER + B` | Web Browser | Launch Google Chrome browser | `google-chrome` |
| `SUPER + N` | Control Center | Toggle Noctalia quick settings and notification center | `noctalia msg panel-toggle control-center` |
| `SUPER + W` | Wallpaper Carousel | Toggle the Noctalia Wallpaper Carousel overlay | `noctalia msg plugin yngwe/wallpaperCarousel:service all toggle` |
| `SUPER + SHIFT + C` | Clipboard Manager | Toggle Noctalia clipboard history overlay | `noctalia msg panel-toggle clipboard` |
| `SUPER + Escape` | Session Lock | Lock screen immediately via loginctl | `loginctl lock-session` |

`SUPER + W` requires the optional Wallpaper Carousel plugin. See [the Noctalia plugin setup](NOCTALIA_WALLPAPER_CAROUSEL.md) for installation and enablement steps.

---

## 2. Window Management and Tiling

| Keybinding | Action | Behavior |
| :--- | :--- | :--- |
| `SUPER + Q` | Close Window | Closes the focused active window (`killactive`) |
| `SUPER + V` | Toggle Floating | Toggles floating mode on active window (`togglefloating`) |
| `SUPER + F` | Fullscreen | Toggles true fullscreen mode (`fullscreen, 0`) |
| `F11` | Fullscreen | Standard function key fullscreen toggle (`fullscreen, 0`) |
| `SUPER + P` | Pseudotile | Toggles pseudotile mode preserving window aspect ratio (`pseudo`) |
| `SUPER + S` | Toggle Split | Toggles horizontal vs vertical split layout (`layoutmsg, togglesplit`) |
| `SUPER + SHIFT + M` | Exit Hyprland | Terminates compositor session safely with modifier requirement |

---

## 3. Focus Navigation

Directional focus navigation is mapped to both standard cursor arrow keys and standard Vim directional keys (`H`, `J`, `K`, `L`):

| Keybinding | Direction |
| :--- | :--- |
| `SUPER + Left` or `SUPER + H` | Focus window to the left |
| `SUPER + Right` or `SUPER + L` | Focus window to the right |
| `SUPER + Up` or `SUPER + K` | Focus window upward |
| `SUPER + Down` or `SUPER + J` | Focus window downward |

---

## 4. Window Movement and Relocation

Active windows can be moved within the current tiling layout by adding `SHIFT` to directional keys:

| Keybinding | Direction |
| :--- | :--- |
| `SUPER + SHIFT + Left` or `SUPER + SHIFT + H` | Move active window left |
| `SUPER + SHIFT + Right` or `SUPER + SHIFT + L` | Move active window right |
| `SUPER + SHIFT + Up` or `SUPER + SHIFT + K` | Move active window up |
| `SUPER + SHIFT + Down` or `SUPER + SHIFT + J` | Move active window down |

---

## 5. Workspace Navigation and Window Transfer

Workspaces 1 through 10 are bound directly to numeric keys:

| Keybinding | Target Workspace |
| :--- | :--- |
| `SUPER + 1` through `SUPER + 9` | Switch focus directly to workspace 1 through 9 |
| `SUPER + 0` | Switch focus directly to workspace 10 |
| `SUPER + SHIFT + 1` through `SUPER + SHIFT + 9` | Move focused window to workspace 1 through 9 |
| `SUPER + SHIFT + 0` | Move focused window to workspace 10 |

## 6. Screenshots

Screenshots are driven natively via Noctalia Desktop Shell v5's built-in screenshot engine:

| Keybinding | Scope | Action |
| :--- | :--- | :--- |
| `Print` | Full Screen | `noctalia msg screenshot-fullscreen` |
| `SUPER + Print` | Interactive Region | `noctalia msg screenshot-region` |
| `SUPER + SHIFT + S` | Interactive Region | `noctalia msg screenshot-region` (standard shortcut) |

---

## 7. Media, Audio, and Brightness

Hardware media keys are handled via `wpctl` (PipeWire wireplumber) and `brightnessctl`:

| Keybinding | Function | Action |
| :--- | :--- | :--- |
| `XF86AudioRaiseVolume` | Audio Volume | Increase volume by 5% up to 150% maximum limit |
| `XF86AudioLowerVolume` | Audio Volume | Decrease volume by 5% |
| `XF86AudioMute` | Audio Mute | Toggle active audio sink mute status |
| `XF86MonBrightnessUp` | Screen Brightness | Increase display backlight by 5% |
| `XF86MonBrightnessDown` | Screen Brightness | Decrease display backlight by 5% |

---

## 8. Mouse Bindings

Floating windows can be manipulated directly using pointer gestures with the `SUPER` modifier:

| Mouse Input | Action |
| :--- | :--- |
| `SUPER + Left Mouse Drag` | Move floating window across workspace |
| `SUPER + Right Mouse Drag` | Resize floating window boundaries |
