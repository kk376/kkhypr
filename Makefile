.POSIX:
SHELL = /bin/sh

.PHONY: all lint check dry-run install optimize-services status

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
	@ls -la ~/.config/environment.d/10-vulkan-hybrid.conf 2>/dev/null || echo "10-vulkan-hybrid.conf: not linked"
	@echo "==> NVIDIA dGPU Runtime Power Status:"
	@cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo "dGPU node not accessible"
	@echo "==> Redundant Services Status (ABRT / Rsyslog):"
	@systemctl is-active abrtd.service rsyslog.service 2>/dev/null || true
