-- ==============================================================================
-- kkhypr: Production Hyprland Configuration (Lua)
-- Hardware Target: AMD Ryzen 5 7535HS (Radeon 680M) + NVIDIA GeForce RTX 2050 Mobile
-- Shell: Noctalia Desktop Shell v5
-- Terminal: Ghostty
-- ==============================================================================

--------------------------------------------------------------------------------
-- 1. Hardware & Multi-GPU Zero-Freeze Architecture
--------------------------------------------------------------------------------
-- Force Aquamarine/DRM to bind to the integrated AMD Radeon 680M (card1).
-- The NVIDIA RTX 2050 (card0) remains secondary and sleeps in ACPI D3cold.
-- Note: Aquamarine splits AQ_DRM_DEVICES on ':', so by-path PCI addresses with colons must not be used.
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

-- Prevent Vulkan ICD loader from scanning the sleeping NVIDIA card on desktop app launch.
-- Eliminates the 2 to 3 second GTK4/Libadwaita application startup freeze.
hl.env("VK_LOADER_DRIVERS_SELECT", "*radeon*")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. os.getenv("HOME") .. "/.cargo/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))

--------------------------------------------------------------------------------
-- 2. Toolkit & Wayland Integration
--------------------------------------------------------------------------------
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("ADW_DISABLE_PORTAL", "1")

-- GTK3/GTK4 real-time stylesheet live reload across wallpaper changes
local existing_preload = os.getenv("LD_PRELOAD")
local live_reload_so   = os.getenv("HOME") .. "/.local/lib/libgtk-live-reload.so"
if existing_preload and #existing_preload > 0 and not string.find(existing_preload, "libgtk-live-reload.so") then
    hl.env("LD_PRELOAD", live_reload_so .. ":" .. existing_preload)
else
    hl.env("LD_PRELOAD", live_reload_so)
end

-- XWayland fractional scale fix: prevent compositor upscaling, let toolkits handle DPI.
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})

--------------------------------------------------------------------------------
-- 3. Monitor Setup
--------------------------------------------------------------------------------
-- Laptop primary eDP-1 display at native resolution and highest refresh rate.
-- 1.25x fractional scale provides a comfortable 1536x864 equivalent UI space.
-- Extra monitors fallback to preferred mode and auto position.
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144.42",
    position = "0x0",
    scale    = 1.25,
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

--------------------------------------------------------------------------------
-- 4. Default Programs
--------------------------------------------------------------------------------
local terminal    = "ghostty"
local fileManager = "nautilus --new-window"
local browser     = "google-chrome"
local menu          = "noctalia msg panel-toggle launcher"
local clipboard     = "noctalia msg panel-toggle clipboard"
local controlCenter = "noctalia msg panel-toggle control-center"
local editor        = os.getenv("HOME") .. "/.local/bin/zed"
local code          = "code"

--------------------------------------------------------------------------------
-- 5. Autostart Pipeline
--------------------------------------------------------------------------------
hl.on("hyprland.start", function ()
    -- Synchronize environment to D-Bus and systemd user services
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_CLASS VK_LOADER_DRIVERS_SELECT AQ_DRM_DEVICES LIBVA_DRIVER_NAME VDPAU_DRIVER __GLX_VENDOR_LIBRARY_NAME ADW_DISABLE_PORTAL LD_PRELOAD")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_CLASS VK_LOADER_DRIVERS_SELECT AQ_DRM_DEVICES LIBVA_DRIVER_NAME VDPAU_DRIVER __GLX_VENDOR_LIBRARY_NAME ADW_DISABLE_PORTAL LD_PRELOAD")
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- Authentication agent
    hl.exec_cmd("/usr/libexec/hyprpolkitagent")

    -- Noctalia desktop shell (bar, launcher, notifications, widgets)
    hl.exec_cmd("noctalia")

    -- Idle management daemon
    hl.exec_cmd("hypridle")

    -- Dynamic workspace compactor daemon
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/compact_workspaces.py")

    -- Enable caffeine by default (idle inhibitor)
    hl.exec_cmd("sh -c 'sleep 1 && noctalia msg caffeine-enable'")

    -- File manager pre-warmed background service (eliminates cold-start latency)
    hl.exec_cmd("nautilus --gapplication-service")
end)

--------------------------------------------------------------------------------
-- 6. Look & Feel
--------------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in          = 4,
        gaps_out         = 8,
        border_size      = 2,
        col = {
            active_border   = { colors = { "rgba(7aa2f7ee)", "rgba(bb9af7ee)" }, angle = 45 },
            inactive_border = "rgba(1f2335aa)",
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 8,
        active_opacity   = 1.0,
        inactive_opacity = 0.95,

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            vibrancy          = 0.20,
            vibrancy_darkness = 0.05,
            noise             = 0.0,
            contrast          = 0.95,
            brightness        = 0.90,
            ignore_opacity    = true,
            new_optimizations = true,
            popups            = true,
        },

        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 3,
            color        = "rgba(0a0a0fee)",
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        vrr                      = 1,
        focus_on_activate        = true,
    },

    input = {
        kb_layout          = "us",
        numlock_by_default = true,
        follow_mouse       = 1,
        sensitivity        = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = true,
            scroll_factor  = 0.8,
        },
    },

    cursor = {
        no_hardware_cursors = false,
        no_break_fs_vrr     = 2,
        min_refresh_rate    = 60,
    },

    render = {
        direct_scanout = 0,
    },

    debug = {
        vfr = false,
    },
})

--------------------------------------------------------------------------------
-- 7. Animations
--------------------------------------------------------------------------------
hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0},    {0.35, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("snappy",         { type = "bezier", points = { {0.16, 1},    {0.3, 1}  } })
hl.curve("smoothOut",      { type = "bezier", points = { {0.25, 1},    {0.5, 1}  } })
hl.curve("easeOutCubic",   { type = "bezier", points = { {0.33, 1},    {0.68, 1} } })
hl.curve("smoothSlide",    { type = "bezier", points = { {0.25, 0.1},  {0.25, 1.0} } })
hl.curve("smoothSnappy",   { type = "bezier", points = { {0.2, 0.8},   {0.2, 1.0} } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.2,  bezier = "smoothSnappy", style = "slide" })

--------------------------------------------------------------------------------
-- 8. Gestures
--------------------------------------------------------------------------------
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

--------------------------------------------------------------------------------
-- 9. Noctalia Layer & Window Rules
--------------------------------------------------------------------------------
hl.layer_rule({
    name         = "noctalia-blur",
    match        = { namespace = "noctalia.*" },
    blur         = true,
    ignore_alpha = 0.1,
    blur_popups  = true,
})

hl.layer_rule({
    name         = "noctalia-bar-blur",
    match        = { namespace = "noctalia-bar-default" },
    blur         = true,
    ignore_alpha = 0.1,
})

-- Glassmorphism & opacity rules for editors (VSCode, VSCodium, Zed, Neovide)
hl.window_rule({
    name    = "code-opacity",
    match   = { class = "^(com\\.microsoft\\.VSCode|code|Code|code-oss|VSCodium|codium|com\\.vscodium\\.codium)$" },
    opacity = "0.75 0.75",
})
hl.window_rule({
    name    = "zed-opacity",
    match   = { class = "^(dev\\.zed\\.Zed|zed)$" },
    opacity = "0.75 0.75",
})
hl.window_rule({
    name    = "neovide-opacity",
    match   = { class = "^(neovide)$" },
    opacity = "0.75 0.75",
})
hl.window_rule({
    name    = "noctalia-settings-opacity",
    match   = { class = "^(dev\\.noctalia\\.Noctalia)$" },
    opacity = "0.92 0.88",
})

-- Floating utility rules
hl.window_rule({
    name  = "pavucontrol-float",
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
})

hl.window_rule({
    name  = "nm-connection-editor-float",
    match = { class = "nm-connection-editor" },
    float = true,
})

hl.window_rule({
    name  = "hyprpolkitagent-float",
    match = { class = "hyprpolkitagent" },
    float = true,
})

hl.window_rule({
    name  = "open-file-float",
    match = { title = "Open File" },
    float = true,
})

hl.window_rule({
    name  = "save-file-float",
    match = { title = "Save File" },
    float = true,
})

hl.window_rule({
    name  = "hyprland-dialog-float",
    match = { class = "hyprland-dialog" },
    float = true,
})

--------------------------------------------------------------------------------
-- 10. Keybindings
--------------------------------------------------------------------------------
local mainMod = "SUPER"

-- Applications
hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T",             hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + space",         hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + C",             hl.dsp.exec_cmd(code))
hl.bind(mainMod .. " + N",             hl.dsp.exec_cmd(controlCenter))
hl.bind(mainMod .. " + B",             hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Z",             hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + SHIFT + C",     hl.dsp.exec_cmd(clipboard))
hl.bind(mainMod .. " + Escape",        hl.dsp.exec_cmd("loginctl lock-session"))

-- Window management
hl.bind(mainMod .. " + Q",             hl.dsp.window.close())
hl.bind(mainMod .. " + V",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind("F11",                         hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))
hl.bind(mainMod .. " + P",             hl.dsp.window.pseudo())
hl.bind(mainMod .. " + S",             hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + M",     hl.dsp.exit())

-- Focus navigation (Vim & Arrow keys)
hl.bind(mainMod .. " + left",          hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",         hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",            hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",          hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + h",             hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l",             hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k",             hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j",             hl.dsp.focus({ direction = "down" }))

-- Window movement (Vim & Arrow keys)
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + h",     hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + l",     hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + k",     hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + j",     hl.dsp.window.move({ direction = "down" }))

-- Workspaces 1 to 10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,              hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,      hl.dsp.window.move({ workspace = i }))
end

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware keys: Audio & Brightness
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd("brightnessctl set 5%+"),                            { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd("brightnessctl set 5%-"),                            { locked = true, repeating = true })

-- Screenshots
local screenshotScript = os.getenv("HOME") .. "/.config/hypr/scripts/screenshot.sh"
hl.bind("Print",                          hl.dsp.exec_cmd(screenshotScript .. " area"))
hl.bind(mainMod .. " + Print",            hl.dsp.exec_cmd(screenshotScript .. " screen"))
hl.bind(mainMod .. " + SHIFT + Print",    hl.dsp.exec_cmd(screenshotScript .. " screen-save"))
hl.bind(mainMod .. " + SHIFT + Sys_Req",  hl.dsp.exec_cmd(screenshotScript .. " screen-save"))



-- For Noctalia Color templates
require("noctalia").apply_theme()
