# Noctalia Wallpaper Carousel

`kkhypr` includes a `SUPER + W` binding for the third-party [Wallpaper Carousel](https://github.com/motor-dev/wallpaperCarousel) plugin. The plugin is not vendored in this repository; install it separately into Noctalia's local plugin directory.

## Requirements

- Noctalia v5 with wallpaper management enabled
- A wallpaper folder configured in Noctalia or in the plugin's settings

## Install and enable

Clone the plugin into Noctalia's data directory. `NOCTALIA_DATA_HOME` and `XDG_DATA_HOME` are honored; the default is `~/.local/share`.

```sh
data_home="${NOCTALIA_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}}"
mkdir -p "$data_home/noctalia/plugins"
git clone https://github.com/motor-dev/wallpaperCarousel \
  "$data_home/noctalia/plugins/wallpaperCarousel"
```

Start Noctalia, then enable the plugin from Settings → Plugins, or run:

```sh
noctalia msg plugins enable yngwe/wallpaperCarousel
```

The command needs a running Noctalia instance. Noctalia saves plugin enablement in its app-managed state under `$XDG_STATE_HOME/noctalia/settings.toml` (normally `~/.local/state/noctalia/settings.toml`; `NOCTALIA_STATE_HOME` can override it). If the plugin files are present but it does not load, make sure this saved `[plugins].enabled` list includes `yngwe/wallpaperCarousel`. Enabling the plugin through the UI or CLI updates that list. It overrides `plugins.enabled` from `config.toml`, so adding the plugin only to the repository's config file is not enough on a machine with an existing settings override.

Use the data-directory path above for Noctalia v5. The repository tracks its own `custom_bar` plugin under `dotfiles/noctalia/plugins/`; keep this third-party checkout in Noctalia's local data directory. That local copy takes precedence over plugin sources.

## Choose the wallpaper folder

Noctalia must manage the desktop wallpaper for the plugin to apply selections. If Noctalia's wallpaper directory is unset, open Settings → Plugins → Wallpaper Carousel and set `wallpaperDirectory` to the folder containing your images, for example `~/Pictures/Wallpapers`.

## Use

Press `SUPER + W` to toggle the carousel. The binding runs:

```sh
noctalia msg plugin yngwe/wallpaperCarousel:service all toggle
```

The binding is configured in `dotfiles/hypr/hyprland.lua`. Reload Hyprland after installing or updating the dotfiles.
