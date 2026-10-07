# Flatpak Terminal Progress Flicker

## Problem

Flatpak installation, removal and update operations can cause noticeable
terminal/display flickering during their progress output.

This behaviour was also observed in GNOME and during Flatpak-related testing
from WSL, indicating that it is not specific to Hyprland's compositor or VRR
configuration.

Therefore this does not appear to be specific to Hyprland's VRR configuration.

## Investigation

The following Flatpak output modes were compared.

Testing was performed through a pseudo-TTY using `script` so that the
different Flatpak output modes could be compared under the same terminal
conditions.

### TTY progress disabled

```bash
script -q -c \
  'FLATPAK_TTY_PROGRESS=0 flatpak --system install --assumeyes flathub org.kde.dolphin' \
  /dev/null
```

Result:

```text
Least flicker.
```

### Fancy output disabled

```bash
script -q -c \
  'FLATPAK_FANCY_OUTPUT=0 flatpak --system install --assumeyes flathub org.kde.dolphin' \
  /dev/null
```

Result:

```text
Most flicker.
```

### Standard/default Flatpak output

```bash
script -q -c \
  'flatpak --system install --assumeyes flathub org.kde.dolphin' \
  /dev/null
```

Result:

```text
Less flicker than FLATPAK_FANCY_OUTPUT=0,
but more flicker than FLATPAK_TTY_PROGRESS=0.
```

## Conclusion

The flickering is associated with Flatpak's terminal progress rendering.

The testing does not justify changing the system's normal Flatpak behaviour,
because the default method was acceptable and the user preferred to keep
Flatpak unmodified.

No permanent `FLATPAK_TTY_PROGRESS` or `FLATPAK_FANCY_OUTPUT` override was
adopted.

The `script` utility was used only as a testing mechanism and is not part of
the final configuration.

## Final Decision

Use standard Flatpak commands normally:

```bash
flatpak install flathub <application>
flatpak uninstall <application>
flatpak update
```

No Flatpak wrapper or environment override is required.

## Testing Note

`util-linux-script` was temporarily installed to provide the `script`
command for pseudo-TTY testing. It is not required for normal Flatpak usage.
