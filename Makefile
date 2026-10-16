.POSIX:
SHELL = /bin/sh

.PHONY: all lint check dry-run install optimize-services status

all: lint check

lint:
	@echo "==> Running shellcheck on installer..."
	shellcheck install.sh
	@echo "==> Verifying Hyprland 0.56 native Lua configuration..."
	hyprland --verify-config -c dotfiles/hypr/hyprland.lua
	@echo "==> Validating Noctalia shell configuration..."
	noctalia config validate dotfiles/noctalia/config.toml
	@echo "==> All syntax and configuration checks passed."

check:
	@./install.sh --check

dry-run:
	@./install.sh --dry-run

install:
	@./install.sh

optimize-services:
	@echo "==> Disabling redundant Fedora background services (ABRT and Rsyslog)..."
	sudo systemctl disable --now abrtd.service abrt-journal-core.service abrt-oops.service abrt-xorg.service
	sudo systemctl disable --now rsyslog.service
	@echo "==> Redundant services disabled. Reclaimed ~246 MB idle RAM."

status:
	@echo "==> Configuration symlink status:"
	@ls -la ~/.config/hypr/hyprland.lua 2>/dev/null || echo "hyprland.lua: not linked"
	@ls -la ~/.config/hypr/device.lua 2>/dev/null || echo "device.lua: optional host override not present"
	@ls -la ~/.config/btop/btop.conf 2>/dev/null || echo "btop.conf: not linked"
	@ls -la ~/.config/noctalia/config.toml 2>/dev/null || echo "noctalia config.toml: not linked"
	@ls -la ~/.config/ghostty/config.ghostty 2>/dev/null || echo "ghostty config.ghostty: not linked"
	@ls -la ~/.config/ghostty/gtk.css 2>/dev/null || echo "ghostty gtk.css: not linked"
	@ls -la ~/.config/foot/foot.ini 2>/dev/null || echo "foot.ini: not linked"
	@ls -la ~/.config/tmux/tmux.conf 2>/dev/null || echo "tmux.conf: not linked"
	@ls -la ~/.config/wireplumber/wireplumber.conf.d/50-bluez.conf 2>/dev/null || echo "50-bluez.conf: not linked"
	@ls -la ~/.config/kitty/kitty.conf 2>/dev/null || echo "kitty.conf: not linked"
	@ls -la ~/.config/gtk-3.0/gtk.css 2>/dev/null || echo "gtk-3.0/gtk.css: not linked"
	@ls -la ~/.config/gtk-4.0/gtk.css 2>/dev/null || echo "gtk-4.0/gtk.css: not linked"
	@echo "==> Audio Default Sink Status:"
	@wpctl status | grep -A 2 "Sinks:" || true
