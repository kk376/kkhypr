# Hybrid GPU Power Management and DRM Routing

This guide explains how `kkhypr` achieves zero desktop micro-freezes and maximum battery life on hybrid AMD and NVIDIA laptops.

---

## The Hybrid GPU Problem

Hybrid laptops feature two graphics processors:
1. An integrated graphics processor (iGPU) integrated within the CPU (such as AMD Radeon 680M) that drives display outputs with low power draw.
2. A discrete graphics processor (dGPU) from NVIDIA (such as RTX 2050 Mobile) designed for heavy compute and 3D rendering.

Under the Linux kernel, device discovery order determines the DRM card indices:
* If the PCI bus enumerates the discrete GPU first, `/dev/dri/card0` becomes the NVIDIA controller.
* The integrated processor is assigned `/dev/dri/card1`.

When a Wayland compositor starts or when GTK4 applications launch, standard graphics libraries probe all available device nodes under `/dev/dri/` and enumerate all Vulkan ICD loaders under `/usr/share/vulkan/icd.d/`.

When `/dev/dri/card0` or the NVIDIA Vulkan driver is queried, the Linux kernel wakes the sleeping NVIDIA controller from the ACPI D3cold power state into full D0 power state. This transition requires the hardware to power up rails, initialize clocks, and handshake over PCIe, causing a noticeable 2 to 3 second desktop freeze.

Once awake, background polling often keeps the dGPU active, consuming 15 to 25 watts of battery power and generating unnecessary thermal load.

---

## The kkhypr Solution: Modular Device Overrides

Rather than hardcoding GPU vendor parameters into universal compositor dotfiles, `kkhypr` decouples hardware-specific environment overrides into `~/.config/hypr/device.lua` (see template `dotfiles/hypr/device.lua.example`):

```lua
-- ~/.config/hypr/device.lua

-- Explicit DRM device priority for Hyprland Aquamarine backend
-- Prioritize integrated GPU (e.g. card1) over secondary dGPU (card0)
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

-- Restrict desktop Vulkan driver discovery to integrated Mesa driver
-- Prevents GTK4 and Chromium from probing sleeping NVIDIA cards
hl.env("VK_LOADER_DRIVERS_SELECT", "*radeon*")

-- Hardware acceleration and Mesa library bindings
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
```

### Explanation of Rules

1. **`AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0`**:
   Instructs the Aquamarine backend to prioritize `card1` (e.g. AMD Radeon or Intel iGPU) for primary presentation buffers, page flips, and monitor outputs. The discrete GPU is only used as a secondary device when explicitly directed.
   * Important: Aquamarine splits device strings by colon (`:`). Direct card nodes (`/dev/dri/card1:/dev/dri/card0`) must be used.

2. **`VK_LOADER_DRIVERS_SELECT=*radeon*`**:
   The Vulkan Loader Specification supports `VK_LOADER_DRIVERS_SELECT` to filter active ICD filenames using glob patterns. Setting this variable to your integrated driver (`*radeon*` or `*intel*`) ensures GTK4, Libadwaita, and browser engines only initialize integrated ICDs, preventing probes into `nvidia_icd.json`.

---

## Verifying Power State

To verify that your discrete GPU is sleeping in D3cold during standard desktop use, locate your dGPU PCI bus ID (via `lspci | grep -i 'vga\|3d'`) and check runtime power status:

```bash
# Example for PCI address 0000:01:00.0:
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
```

Expected output:
```text
suspended
```

If the status reports `active`, check which process is holding open a device node:

```bash
lsof /dev/nvidia* /dev/dri/card0
```

---

## Running Applications on the NVIDIA dGPU (Prime Offload)

When you intentionally want to launch a 3D game, compute job, or heavy rendering application on the discrete NVIDIA GPU, run the application using prime offload environment variables:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia <application>
```

For Steam games, set the game launch options:
```text
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

When the application closes, the kernel runtime power management automatically returns the NVIDIA GPU to `suspended` D3cold within several seconds.
