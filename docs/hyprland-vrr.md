# Hyprland VRR / VFR Display Behaviour

## Hardware

- Panel: AU Optronics 0xD0A2
- Resolution: 1920x1080
- Maximum refresh rate: 144.42 Hz
- VRR range reported by AMDGPU: 48–144 Hz
- GPU setup:
  - AMD Radeon 680M iGPU
  - NVIDIA RTX 2050 Mobile

## Problem

While using Hyprland, enabling VRR together with Variable Frame Rate (VFR)
caused visible gamma/brightness flickering on the internal display.

The effect was particularly noticeable during very fast scrolling in Neovim.

The same behaviour was not observed to the same degree in GNOME or Windows,
suggesting that compositor/frame-scheduling behaviour influences how strongly
the panel's VRR behaviour is exposed.

## Investigation

### VRR ON + VFR ON

```text
VRR: ON
VFR: ON
```

Result:

- Significant gamma flickering.
- Flickering became more noticeable during rapid scrolling.
- Hyprland's FPS overlay could drop substantially during rendering.

### VRR OFF + VFR ON

```text
VRR: OFF
VFR: ON
```

Result:

- Flickering disappeared.
- Noticeable rendering/display jitter appeared instead.

### VRR OFF + VFR OFF

```text
VRR: OFF
VFR: OFF
```

Result:

- No significant VRR-related flickering.
- Jitter remained.
- Hyprland's rendered FPS could drop to around 70 FPS during heavy
  Neovim scrolling.

### VRR ON + VFR OFF

```text
VRR: ON
VFR: OFF
```

Result:

- Smoothest overall behaviour.
- Only very minor flickering remained during extremely rapid
  Neovim Ctrl-D/Ctrl-U scrolling.
- Observed rendered FPS was approximately 133–134 FPS when the
  remaining flicker occurred.
- Normal desktop usage was effectively smooth.

## VRR Range

The panel's VRR range was checked directly through AMDGPU debugfs:

```bash
sudo cat /sys/kernel/debug/dri/1/eDP-1/vrr_range
```

Result:

```text
Min: 48
Max: 144
```

Therefore the panel/driver advertises a VRR range of 48–144 Hz.

The low FPS shown by Hyprland's debug overlay should not be interpreted as
the physical panel literally operating at that refresh rate. The overlay
represents compositor rendering/presentation behaviour, not necessarily the
panel's instantaneous physical refresh rate.

## Final Configuration

The current configuration intentionally keeps VRR enabled while disabling
Hyprland VFR:

```lua
cursor = {
    no_hardware_cursors = false,
    no_break_fs_vrr     = 2,
    min_refresh_rate    = 60,
},

misc = {
    vrr = 1,
},

render = {
    direct_scanout = 0,
},

debug = {
    vfr = false,
},
```

Runtime verification:

```bash
hyprctl getoption misc:vrr
hyprctl getoption debug:vfr
hyprctl getoption cursor:no_break_fs_vrr
hyprctl getoption cursor:min_refresh_rate
```

Expected state:

```text
misc.vrr = 1
debug.vfr = false
cursor:no_break_fs_vrr = 2
cursor:min_refresh_rate = 60
```

## Decision

The remaining flicker is extremely minor and only reproducible under an
unusually aggressive scrolling workload.

Disabling VRR eliminates the flicker but introduces noticeably worse
jitter. Enabling VFR makes the VRR flickering substantially worse.

Therefore the chosen configuration is:

```text
VRR: ON
VFR: OFF
```

This provides the best practical balance between smoothness and display
stability on this particular panel.

Further investigation or EDID/VRR-range modification is not considered
worthwhile unless the behaviour becomes significantly worse.

## Notes

This appears to be an interaction between:

1. The AU Optronics panel's VRR behaviour.
2. AMDGPU/DRM.
3. Hyprland's frame scheduling/presentation behaviour.

It should not be treated as a general Hyprland configuration requirement.
Other panels and compositor combinations may behave differently.
