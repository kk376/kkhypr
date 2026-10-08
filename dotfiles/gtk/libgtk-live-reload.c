#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <glib.h>
#include <gio/gio.h>

/*
 * libgtk-live-reload: Zero-overhead dynamic stylesheet reload shim for GTK3 and GTK4.
 *
 * Automatically monitors ~/.config/gtk-4.0/gtk.css, ~/.config/gtk-4.0/noctalia.css,
 * ~/.config/gtk-3.0/gtk.css, and ~/.config/gtk-3.0/noctalia.css.
 * Attaches a GtkCssProvider at priority 810 (GTK_STYLE_PROVIDER_PRIORITY_USER + 10)
 * and reloads styles in running GTK processes in real time (<50ms) upon wallpaper
 * or palette changes without requiring application restarts.
 */

typedef void* (*t_gtk_css_provider_new)(void);
typedef void  (*t_gtk4_css_provider_load_from_path)(void*, const char*);
typedef int   (*t_gtk3_css_provider_load_from_path)(void*, const char*, void**);
typedef void* (*t_gdk_display_get_default)(void);
typedef void  (*t_gtk_style_context_add_provider_for_display)(void*, void*, unsigned int);
typedef void* (*t_gdk_screen_get_default)(void);
typedef void  (*t_gtk_style_context_add_provider_for_screen)(void*, void*, unsigned int);
typedef void* (*t_gtk_settings_get_default)(void);

static void *g_provider4 = NULL;
static void *g_provider3 = NULL;
static char g_css4_path[1024] = {0};
static char g_css3_path[1024] = {0};

static t_gtk4_css_provider_load_from_path fn_load4 = NULL;
static t_gtk3_css_provider_load_from_path fn_load3 = NULL;

static struct timespec last_reload4 = {0, 0};
static struct timespec last_reload3 = {0, 0};
static int g_settings_connected = 0;
static int g_idle_scheduled = 0;

static long time_diff_ms(struct timespec *t1, struct timespec *t2) {
    return (t1->tv_sec - t2->tv_sec) * 1000L + (t1->tv_nsec - t2->tv_nsec) / 1000000L;
}

static void resolve_path(const char *rel_path, char *out, size_t out_len) {
    const char *home = getenv("HOME");
    if (!home) return;
    char raw[1024];
    snprintf(raw, sizeof(raw), "%s/%s", home, rel_path);
    char resolved[1024];
    if (realpath(raw, resolved)) {
        snprintf(out, out_len, "%s", resolved);
    } else {
        snprintf(out, out_len, "%s", raw);
    }
}

static void reload_gtk4_now(void) {
    if (!g_provider4 || !fn_load4 || !g_css4_path[0]) return;
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (time_diff_ms(&now, &last_reload4) < 50) return;
    last_reload4 = now;

    resolve_path(".config/gtk-4.0/gtk.css", g_css4_path, sizeof(g_css4_path));
    fn_load4(g_provider4, g_css4_path);
}

static void reload_gtk3_now(void) {
    if (!g_provider3 || !fn_load3 || !g_css3_path[0]) return;
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    if (time_diff_ms(&now, &last_reload3) < 50) return;
    last_reload3 = now;

    resolve_path(".config/gtk-3.0/gtk.css", g_css3_path, sizeof(g_css3_path));
    fn_load3(g_provider3, g_css3_path, NULL);
}

static void on_fs_change(GFileMonitor *monitor, GFile *file, GFile *other_file, GFileMonitorEvent event_type, gpointer user_data) {
    (void)monitor; (void)file; (void)other_file; (void)event_type; (void)user_data;
    reload_gtk4_now();
    reload_gtk3_now();
}

static void on_theme_setting_changed(GObject *settings, GParamSpec *pspec, gpointer user_data) {
    (void)settings; (void)pspec; (void)user_data;
    reload_gtk4_now();
    reload_gtk3_now();
}

static void attach_file_and_dir_monitor(const char *file_path) {
    GFile *f = g_file_new_for_path(file_path);
    if (!f) return;

    GFileMonitor *m_file = g_file_monitor_file(f, G_FILE_MONITOR_NONE, NULL, NULL);
    if (m_file) {
        g_signal_connect(m_file, "changed", G_CALLBACK(on_fs_change), NULL);
    }

    GFile *parent = g_file_get_parent(f);
    if (parent) {
        GFileMonitor *m_dir = g_file_monitor_directory(parent, G_FILE_MONITOR_NONE, NULL, NULL);
        if (m_dir) {
            g_signal_connect(m_dir, "changed", G_CALLBACK(on_fs_change), NULL);
        }
        g_object_unref(parent);
    }

    g_object_unref(f);
}

static void ensure_gtk_providers(void) {
    if (g_provider4 || g_provider3) return;

    t_gtk_css_provider_new fn_new = (t_gtk_css_provider_new)dlsym(RTLD_DEFAULT, "gtk_css_provider_new");
    if (!fn_new) return;

    // Check GTK4 Display
    t_gdk_display_get_default fn_display = (t_gdk_display_get_default)dlsym(RTLD_DEFAULT, "gdk_display_get_default");
    t_gtk_style_context_add_provider_for_display fn_add4 = (t_gtk_style_context_add_provider_for_display)dlsym(RTLD_DEFAULT, "gtk_style_context_add_provider_for_display");
    if (fn_display && fn_add4 && !g_provider4) {
        void *display = fn_display();
        if (display) {
            fn_load4 = (t_gtk4_css_provider_load_from_path)dlsym(RTLD_DEFAULT, "gtk_css_provider_load_from_path");
            if (fn_load4) {
                resolve_path(".config/gtk-4.0/gtk.css", g_css4_path, sizeof(g_css4_path));
                char noctalia4[1024];
                resolve_path(".config/gtk-4.0/noctalia.css", noctalia4, sizeof(noctalia4));

                g_provider4 = fn_new();
                fn_add4(display, g_provider4, 810);
                fn_load4(g_provider4, g_css4_path);
                clock_gettime(CLOCK_MONOTONIC, &last_reload4);

                attach_file_and_dir_monitor(g_css4_path);
                if (strcmp(g_css4_path, noctalia4) != 0) {
                    attach_file_and_dir_monitor(noctalia4);
                }
            }
        }
    }

    // Check GTK3 Screen
    t_gdk_screen_get_default fn_screen = (t_gdk_screen_get_default)dlsym(RTLD_DEFAULT, "gdk_screen_get_default");
    t_gtk_style_context_add_provider_for_screen fn_add3 = (t_gtk_style_context_add_provider_for_screen)dlsym(RTLD_DEFAULT, "gtk_style_context_add_provider_for_screen");
    if (fn_screen && fn_add3 && !g_provider3) {
        void *screen = fn_screen();
        if (screen) {
            fn_load3 = (t_gtk3_css_provider_load_from_path)dlsym(RTLD_DEFAULT, "gtk_css_provider_load_from_path");
            if (fn_load3) {
                resolve_path(".config/gtk-3.0/gtk.css", g_css3_path, sizeof(g_css3_path));
                char noctalia3[1024];
                resolve_path(".config/gtk-3.0/noctalia.css", noctalia3, sizeof(noctalia3));

                g_provider3 = fn_new();
                fn_add3(screen, g_provider3, 810);
                fn_load3(g_provider3, g_css3_path, NULL);
                clock_gettime(CLOCK_MONOTONIC, &last_reload3);

                attach_file_and_dir_monitor(g_css3_path);
                if (strcmp(g_css3_path, noctalia3) != 0) {
                    attach_file_and_dir_monitor(noctalia3);
                }
            }
        }
    }

    // Hook GtkSettings theme property change signals
    if (!g_settings_connected && (g_provider4 || g_provider3)) {
        t_gtk_settings_get_default fn_settings = (t_gtk_settings_get_default)dlsym(RTLD_DEFAULT, "gtk_settings_get_default");
        if (fn_settings) {
            void *settings = fn_settings();
            if (settings) {
                g_signal_connect(settings, "notify::gtk-theme-name", G_CALLBACK(on_theme_setting_changed), NULL);
                g_signal_connect(settings, "notify::gtk-application-prefer-dark-theme", G_CALLBACK(on_theme_setting_changed), NULL);
                g_settings_connected = 1;
            }
        }
    }
}

static gboolean on_idle_setup(gpointer user_data) {
    (void)user_data;
    static int retry_count = 0;

    t_gtk_css_provider_new fn_new = (t_gtk_css_provider_new)dlsym(RTLD_DEFAULT, "gtk_css_provider_new");
    if (!fn_new) {
        g_idle_scheduled = 0;
        return G_SOURCE_REMOVE;
    }

    ensure_gtk_providers();

    if (g_provider4 || g_provider3) {
        g_idle_scheduled = 0;
        return G_SOURCE_REMOVE;
    }

    if (++retry_count > 40) {
        g_idle_scheduled = 0;
        return G_SOURCE_REMOVE;
    }

    return G_SOURCE_CONTINUE;
}

static void schedule_idle_setup(void) {
    if (g_provider4 || g_provider3) return;
    if (g_idle_scheduled) return;
    g_idle_scheduled = 1;
    g_idle_add(on_idle_setup, NULL);
}

void gtk_window_present(void *window) {
    static void (*real_present)(void*) = NULL;
    if (!real_present) real_present = dlsym(RTLD_NEXT, "gtk_window_present");
    ensure_gtk_providers();
    if (real_present) real_present(window);
}

void gtk_window_present_with_time(void *window, unsigned int timestamp) {
    static void (*real_present_time)(void*, unsigned int) = NULL;
    if (!real_present_time) real_present_time = dlsym(RTLD_NEXT, "gtk_window_present_with_time");
    ensure_gtk_providers();
    if (real_present_time) real_present_time(window, timestamp);
}

void gtk_widget_show(void *widget) {
    static void (*real_show)(void*) = NULL;
    if (!real_show) real_show = dlsym(RTLD_NEXT, "gtk_widget_show");
    ensure_gtk_providers();
    if (real_show) real_show(widget);
}

void gtk_widget_set_visible(void *widget, int visible) {
    static void (*real_set_vis)(void*, int) = NULL;
    if (!real_set_vis) real_set_vis = dlsym(RTLD_NEXT, "gtk_widget_set_visible");
    ensure_gtk_providers();
    if (real_set_vis) real_set_vis(widget, visible);
}

void *dlopen(const char *filename, int flag) {
    void *(*real_dlopen)(const char*, int) = dlsym(RTLD_NEXT, "dlopen");
    void *handle = real_dlopen ? real_dlopen(filename, flag) : NULL;
    if (filename && (strstr(filename, "libgtk-4") || strstr(filename, "libgtk-3"))) {
        schedule_idle_setup();
    }
    return handle;
}

int g_application_run(GApplication *app, int argc, char **argv) {
    static int (*real_run)(GApplication*, int, char**) = NULL;
    if (!real_run) real_run = dlsym(RTLD_NEXT, "g_application_run");
    schedule_idle_setup();
    return real_run ? real_run(app, argc, argv) : 0;
}

gboolean g_main_context_iteration(GMainContext *context, gboolean may_block) {
    static gboolean (*real_iter)(GMainContext*, gboolean) = NULL;
    if (!real_iter) real_iter = dlsym(RTLD_NEXT, "g_main_context_iteration");
    if (!g_provider4 && !g_provider3 && !g_idle_scheduled) {
        schedule_idle_setup();
    }
    return real_iter ? real_iter(context, may_block) : FALSE;
}

__attribute__((constructor))
static void ctor(void) {
    // Guarantee Libadwaita bypasses portal and queries GSettings directly for live accent updates
    setenv("ADW_DISABLE_PORTAL", "1", 1);

    if (dlsym(RTLD_DEFAULT, "gtk_style_context_add_provider_for_display") ||
        dlsym(RTLD_DEFAULT, "gtk_style_context_add_provider_for_screen")) {
        ensure_gtk_providers();
        if (!g_provider4 && !g_provider3) {
            schedule_idle_setup();
        }
    }
}
