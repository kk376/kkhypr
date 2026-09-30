.POSIX:
SHELL = /bin/sh

.PHONY: all lint check dry-run install system-install optimize-services status

all: lint check

lint:
	@echo "==> Running shellcheck on installer..."
	shellcheck install.sh
	@echo "==> Verifying Hyprland 0.56 native Lua configuration..."
	hyprland --verify-config -c dotfiles/hypr/hyprland.lua
	@echo "==> Verifying Hyprland 0.56 legacy configuration..."
	hyprland --verify-config -c dotfiles/hypr/hyprland.conf
	@echo "==> Validating Noctalia shell configuration..."
	noctalia config validate dotfiles/noctalia/config.toml
	@echo "==> All syntax and configuration checks passed."

check:
	@./install.sh --check

dry-run:
	@./install.sh --dry-run

install:
	@./install.sh

system-install:
	@echo "==> Deploying system-level GPU isolation and audio contention fixes..."
	sudo ./install.sh --system

optimize-services:
	@echo "==> Disabling redundant Fedora background services (ABRT and Rsyslog)..."
	sudo systemctl disable --now abrtd.service abrt-journal-core.service abrt-oops.service abrt-xorg.service
	sudo systemctl disable --now rsyslog.service
	@echo "==> Redundant services disabled. Reclaimed ~246 MB idle RAM."

status:
	@echo "==> Configuration symlink status:"
	@ls -la ~/.config/hypr/hyprland.lua 2>/dev/null || echo "hyprland.lua: not linked"
	@ls -la ~/.config/hypr/hyprland.conf 2>/dev/null || echo "hyprland.conf: not linked"
	@ls -la ~/.config/noctalia/config.toml 2>/dev/null || echo "noctalia config.toml: not linked"
	@ls -la ~/.config/ghostty/config.ghostty 2>/dev/null || echo "ghostty config.ghostty: not linked"
	@ls -la ~/.config/ghostty/gtk.css 2>/dev/null || echo "ghostty gtk.css: not linked"
	@ls -la ~/.config/wireplumber/wireplumber.conf.d/50-bluez.conf 2>/dev/null || echo "50-bluez.conf: not linked"
	@ls -la ~/.config/environment.d/10-vulkan-hybrid.conf 2>/dev/null || echo "10-vulkan-hybrid.conf: not linked"
	@echo "==> System-wide configuration status:"
	@ls -la /etc/environment.d/10-vulkan-hybrid.conf 2>/dev/null || echo "/etc/environment.d/10-vulkan-hybrid.conf: missing"
	@ls -la /etc/systemd/user/wireplumber.service.d/10-disable-greeter.conf 2>/dev/null || echo "wireplumber greeter drop-in: missing"
	@echo "==> NVIDIA dGPU Runtime Power Status:"
	@cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo "dGPU node not accessible"
	@echo "==> Audio Default Sink Status:"
	@wpctl status | grep -A 2 "Sinks:" || true
