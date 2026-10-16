-- ==============================================================================
-- kkhypr: Production Hyprland Configuration (Native Lua)
-- Target: Fedora 44+, Hyprland 0.56+, Noctalia Desktop Shell v5
-- Architecture: Hardware-Agnostic with Modular Device Overrides
-- ==============================================================================

--------------------------------------------------------------------------------
-- 1. Monitors & Hardware Overrides
--------------------------------------------------------------------------------
-- Default fallback rule: auto detect preferred resolution and position
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Default internal display rule for laptops
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

-- Device override hook: Loads machine-specific display, GPU, or scaling rules
local device_override = os.getenv("HOME") .. "/.config/hypr/device.lua"
local dev_file = io.open(device_override, "r")
if dev_file then
    dev_file:close()
    pcall(dofile, device_override)
end

--------------------------------------------------------------------------------
-- 2. Core Applications
--------------------------------------------------------------------------------
local terminal    = "ghostty"
local fileManager = "flatpak run org.kde.dolphin"
local browser     = "flatpak run com.google.Chrome"

--------------------------------------------------------------------------------
-- 3. Environment Variables
--------------------------------------------------------------------------------
-- Hardware & Multi-GPU Zero-Freeze Architecture
-- Force Aquamarine/DRM to bind to the integrated GPU (e.g. card1).
-- Secondary discrete GPUs (like NVIDIA) sleep in ACPI D3cold.
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")

-- Prevent Vulkan ICD loader from scanning sleeping discrete GPUs on app launch.
-- Eliminates the 2 to 3 second GTK4/Libadwaita application startup freeze.
hl.env("VK_LOADER_DRIVERS_SELECT", "*radeon*")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- GTK3/GTK4 real-time stylesheet live reload across wallpaper changes
hl.env("ADW_DISABLE_PORTAL", "1")
local live_reload_so = os.getenv("HOME") .. "/.local/lib/libgtk-live-reload.so"
if io.open(live_reload_so, "r") then
    hl.env("LD_PRELOAD", live_reload_so)
end

--------------------------------------------------------------------------------
-- 4. Autostart
--------------------------------------------------------------------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_CLASS VK_LOADER_DRIVERS_SELECT AQ_DRM_DEVICES LIBVA_DRIVER_NAME VDPAU_DRIVER __GLX_VENDOR_LIBRARY_NAME ADW_DISABLE_PORTAL LD_PRELOAD")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SESSION_CLASS VK_LOADER_DRIVERS_SELECT AQ_DRM_DEVICES LIBVA_DRIVER_NAME VDPAU_DRIVER __GLX_VENDOR_LIBRARY_NAME ADW_DISABLE_PORTAL LD_PRELOAD")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("noctalia")
    hl.exec_cmd("sh -c 'sleep 1 && noctalia msg caffeine-enable'")
end)

--------------------------------------------------------------------------------
-- 5. Look and Feel
--------------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 1,
        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 0.95,
        inactive_opacity = 0.90,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled      = true,
            size         = 20,
            passes       = 2,
            vibrancy     = 0.2,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Curves & Springs
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("smoothSnappy",   { type = "bezier", points = { {0.2, 0.8},   {0.2, 1.0}   } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- Animation tree
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2.2,  bezier = "smoothSnappy", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

--------------------------------------------------------------------------------
-- 6. Layouts & Input
--------------------------------------------------------------------------------
hl.config({
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
    input = {
        kb_layout      = "us",
        follow_mouse   = 1,
        sensitivity    = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

--------------------------------------------------------------------------------
-- 7. Noctalia v5 Desktop Shell Integration & Blur
--------------------------------------------------------------------------------
hl.layer_rule({
    name         = "noctalia",
    match        = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },
    no_anim      = true,
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})

--------------------------------------------------------------------------------
-- 8. Keybindings (Native Noctalia v5 IPC)
--------------------------------------------------------------------------------
local mainMod = "SUPER"
local ipc     = "noctalia msg "

-- Noctalia UI surfaces
hl.bind(mainMod .. "+Space",         hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))
hl.bind(mainMod .. "+S",             hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
hl.bind(mainMod .. "+N",             hl.dsp.exec_cmd(ipc .. "settings-toggle"))
hl.bind("ALT + Tab",                 hl.dsp.exec_cmd(ipc .. "window-switcher hold"))

-- Hardware & Media keys (routed via Noctalia OSD)
hl.bind("XF86AudioRaiseVolume",      hl.dsp.exec_cmd(ipc .. "volume-up"))
hl.bind("XF86AudioLowerVolume",      hl.dsp.exec_cmd(ipc .. "volume-down"))
hl.bind("XF86AudioMute",             hl.dsp.exec_cmd(ipc .. "volume-mute"))
hl.bind("XF86MonBrightnessUp",       hl.dsp.exec_cmd(ipc .. "brightness-up"))
hl.bind("XF86MonBrightnessDown",     hl.dsp.exec_cmd(ipc .. "brightness-down"))

-- Player controls
hl.bind("XF86AudioNext",             hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause",            hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",             hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",             hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshots (routed via Noctalia screenshot engine)
hl.bind("Print",                     hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen"))
hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd(ipc .. "screenshot-region"))
hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd(ipc .. "screenshot-region"))

-- Window & Session Management
hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + M",           hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + B",           hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",           hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V",           hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P",           hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }))

-- Focus Navigation (Arrow & Vim keys)
hl.bind(mainMod .. " + left",        hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",       hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",          hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",        hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + h",           hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l",           hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k",           hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j",           hl.dsp.focus({ direction = "down" }))

-- Window Movement (Shift + Direction)
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Mouse Bindings
hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",   hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",   hl.dsp.window.resize(), { mouse = true })

--------------------------------------------------------------------------------
-- 9. Window Rules
--------------------------------------------------------------------------------
hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name       = "fix-xwayland-drags",
    match      = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus   = true,
})

hl.window_rule({
    name       = "ayugram-media-viewer-float",
    match      = {
        class = "^(com\\.ayugram\\.desktop|org\\.telegram\\.desktop|AyuGram)$",
        title = "^(Media viewer)$",
    },
    float      = true,
})

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
    name  = "file-dialog-float",
    match = { title = "^(Open File|Save File|Open Folder)$" },
    float = true,
})

--------------------------------------------------------------------------------
-- 10. Dynamic Theme Initialization
--------------------------------------------------------------------------------
require("noctalia").apply_theme()
