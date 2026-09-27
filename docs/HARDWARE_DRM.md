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

## The kkhypr Solution

`kkhypr` provides a multi-layer routing configuration located in `system/environment.d/10-vulkan-hybrid.conf`:

```ini
# Explicit DRM device priority for Hyprland Aquamarine backend
AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0

# Restrict Vulkan driver discovery to Radeon Mesa driver
VK_LOADER_DRIVERS_SELECT=*radeon*

# Hardware acceleration and Mesa library bindings
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
__GLX_VENDOR_LIBRARY_NAME=mesa
```

### Explanation of Rules

1. **`AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0`**:
   Instructs the Aquamarine backend to prioritize `card1` (AMD Radeon 680M) for primary presentation buffers, page flips, and monitor outputs. The NVIDIA card is only used as a secondary device when explicitly directed.
   * Important: Aquamarine splits device strings by colon (`:`). Using PCI path identifiers like `/dev/dri/by-path/pci-0000:01:00.0-card` causes parsing failures due to internal colons. Direct card nodes (`/dev/dri/card1:/dev/dri/card0`) must be used.

2. **`VK_LOADER_DRIVERS_SELECT=*radeon*`**:
   The Vulkan Loader Specification supports `VK_LOADER_DRIVERS_SELECT` to filter active ICD filenames using glob patterns. Setting this variable to `*radeon*` ensures GTK4, Libadwaita, and browser engines only initialize `/usr/share/vulkan/icd.d/radeon_icd.x86_64.json`, preventing probes into `nvidia_icd.json`.

---

## Verifying Power State

To verify that the NVIDIA dGPU is sleeping in D3cold during standard desktop use:

```bash
make status
```

Or query the kernel sysfs directly:

```bash
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
