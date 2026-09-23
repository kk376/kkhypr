.POSIX:
SHELL = /bin/sh

.PHONY: all lint check dry-run install status

all: lint check

lint:
	@echo "==> Running shellcheck on installer..."
	shellcheck install.sh
	@echo "==> Verifying Hyprland 0.56 configuration..."
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

status:
	@echo "==> Configuration symlink status:"
	@ls -la ~/.config/hypr/hyprland.conf 2>/dev/null || echo "hyprland.conf: not linked"
	@ls -la ~/.config/noctalia/config.toml 2>/dev/null || echo "noctalia config.toml: not linked"
	@ls -la ~/.config/environment.d/10-vulkan-hybrid.conf 2>/dev/null || echo "10-vulkan-hybrid.conf: not linked"
	@echo "==> NVIDIA dGPU Runtime Power Status:"
	@cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo "dGPU node not accessible"
