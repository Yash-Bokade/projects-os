/*
 * Projects OS — Native Settings GUI (C11 + GTK4 + GLib GKeyFile)
 * Zero Python dependencies.
 */
#define _POSIX_C_SOURCE 200809L

#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char * const THEME_IDS[] = {
    "matte-dark",
    "carbon-slate",
    "nord-minimal",
    "matte-light",
};

static const char * const THEME_LABELS[] = {
    "Matte Dark (Default)",
    "Carbon Slate",
    "Nord Minimal",
    "Matte Light",
    NULL
};

static const char * const SESSION_IDS[] = {
    "hyprland",
    "niri",
};

static const char * const SESSION_LABELS[] = {
    "Hyprland (Dynamic Tiling)",
    "Niri (Scrollable Tiling)",
    NULL
};

typedef struct {
    const char *key;
    const char *label;
    const char *def_val;
} FieldDef;

static const FieldDef HOTKEYS[] = {
    { "sysmon",         "Toggle System Monitor (btop)",  "S" },
    { "hide_all",       "Hide / Restore All Windows",    "D" },
    { "shortcuts_menu", "Searchable Shortcuts Menu",     "Slash" },
    { "settings",       "Projects OS Settings GUI",      "Comma" },
    { "project_reset",  "Project Reset",                 "Shift+R" },
    { "terminal",       "Launch Terminal (Foot)",        "Return" },
    { "launcher",       "Application Launcher (Fuzzel)", "Space" },
    { "browser",        "Launch Minimal Firefox",        "B" },
    { "neovim",         "Launch Neovim (LazyVim)",       "N" },
    { "localsend",      "Launch LocalSend",              "L" },
    { "obs",            "Launch OBS Studio",             "O" },
    { "close_window",   "Close Focused Window",          "Q" },
};
#define NUM_HOTKEYS (sizeof(HOTKEYS) / sizeof(HOTKEYS[0]))

static const FieldDef PATHS[] = {
    { "projects_dir",        "Projects Workspace Directory",        "Projects" },
    { "obs_recordings",      "OBS Recordings Export Path",          "Exports/OBS" },
    { "localsend_downloads", "LocalSend Downloads Path",            "Exports/LocalSend" },
    { "backup_export",       "Project Archive / Backup Export Path","Exports/Backups" },
};
#define NUM_PATHS (sizeof(PATHS) / sizeof(PATHS[0]))

typedef struct {
    GtkWidget *win;
    GtkWidget *theme_dd;
    GtkWidget *font_spin;
    GtkWidget *session_dd;
    GtkWidget *hotkey_entries[NUM_HOTKEYS];
    GtkWidget *path_entries[NUM_PATHS];
    GtkWidget *status_lbl;
    char *settings_path;
} SettingsState;

static char *get_key_or_default(GKeyFile *kf, const char *group, const char *key, const char *def_val) {
    char *val = g_key_file_get_string(kf, group, key, NULL);
    if (val && val[0] != '\0') return val;
    g_free(val);
    return g_strdup(def_val);
}

static guint find_id_index(const char * const *ids, size_t n, const char *target) {
    if (!target) return 0;
    for (size_t i = 0; i < n; ++i) {
        if (strcmp(ids[i], target) == 0) return (guint)i;
    }
    return 0;
}

static char *read_storage_status(void) {
    FILE *fp = popen("df -h /persist 2>/dev/null || df -h /", "r");
    if (!fp) return g_strdup("Storage info unavailable.");
    GString *out = g_string_new("Persistence Storage Status:\n");
    char buf[256];
    while (fgets(buf, sizeof(buf), fp) != NULL) {
        g_string_append(out, buf);
    }
    pclose(fp);
    return g_string_free(out, FALSE);
}

static void on_open_wizard(GtkButton *btn, gpointer data) {
    (void)btn;
    (void)data;
    gchar *argv[] = { "/usr/local/bin/projects-wizard", NULL };
    g_spawn_async(NULL, argv, NULL, 0, NULL, NULL, NULL, NULL);
}

static void on_reset_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    (void)data;
    gchar *argv[] = { "/usr/local/bin/projects-reset", NULL };
    g_spawn_async(NULL, argv, NULL, 0, NULL, NULL, NULL, NULL);
}

static void on_save_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    SettingsState *st = (SettingsState *)data;

    GKeyFile *kf = g_key_file_new();
    guint theme_idx = gtk_drop_down_get_selected(GTK_DROP_DOWN(st->theme_dd));
    if (theme_idx >= 4) theme_idx = 0;
    guint sess_idx = gtk_drop_down_get_selected(GTK_DROP_DOWN(st->session_dd));
    if (sess_idx >= 2) sess_idx = 0;
    int font_size = gtk_spin_button_get_value_as_int(GTK_SPIN_BUTTON(st->font_spin));

    g_key_file_set_string(kf, "general", "theme", THEME_IDS[theme_idx]);
    g_key_file_set_integer(kf, "general", "font_size", font_size);
    g_key_file_set_string(kf, "general", "default_session", SESSION_IDS[sess_idx]);

    for (size_t i = 0; i < NUM_HOTKEYS; ++i) {
        const char *txt = gtk_editable_get_text(GTK_EDITABLE(st->hotkey_entries[i]));
        g_key_file_set_string(kf, "hotkeys", HOTKEYS[i].key, (txt && txt[0]) ? txt : HOTKEYS[i].def_val);
    }

    for (size_t i = 0; i < NUM_PATHS; ++i) {
        const char *txt = gtk_editable_get_text(GTK_EDITABLE(st->path_entries[i]));
        if (txt && txt[0]) {
            g_key_file_set_string(kf, "paths", PATHS[i].key, txt);
        }
    }

    char *dir = g_path_get_dirname(st->settings_path);
    g_mkdir_with_parents(dir, 0755);
    g_free(dir);

    GError *err = NULL;
    if (!g_key_file_save_to_file(kf, st->settings_path, &err)) {
        gtk_label_set_text(GTK_LABEL(st->status_lbl), err ? err->message : "Failed to save settings.");
        if (err) g_error_free(err);
        g_key_file_free(kf);
        return;
    }
    g_key_file_free(kf);

    int rc = system("/usr/local/bin/projects-apply-config");
    if (rc == 0) {
        gtk_label_set_text(GTK_LABEL(st->status_lbl),
            "Saved & applied live to Hyprland, Niri, Waybar, OBS, LocalSend, and ~/SHORTCUTS.txt.");
    } else {
        gtk_label_set_text(GTK_LABEL(st->status_lbl), "Saved settings.conf (apply hook returned non-zero).");
    }
}

static GtkWidget *build_appearance_tab(SettingsState *st, GKeyFile *kf) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_start(box, 16);
    gtk_widget_set_margin_end(box, 16);

    GtkWidget *row1 = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_append(GTK_BOX(row1), gtk_label_new("Color Theme (Minimalist Solid Matte):"));
    st->theme_dd = gtk_drop_down_new_from_strings(THEME_LABELS);
    char *cur_theme = get_key_or_default(kf, "general", "theme", "matte-dark");
    gtk_drop_down_set_selected(GTK_DROP_DOWN(st->theme_dd), find_id_index(THEME_IDS, 4, cur_theme));
    g_free(cur_theme);
    gtk_box_append(GTK_BOX(row1), st->theme_dd);
    gtk_box_append(GTK_BOX(box), row1);

    GtkWidget *row2 = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_append(GTK_BOX(row2), gtk_label_new("UI & Terminal Font Size (px):"));
    st->font_spin = gtk_spin_button_new_with_range(9.0, 20.0, 1.0);
    GError *err = NULL;
    int fs = g_key_file_get_integer(kf, "general", "font_size", &err);
    if (err || fs < 9 || fs > 20) fs = 12;
    if (err) g_error_free(err);
    gtk_spin_button_set_value(GTK_SPIN_BUTTON(st->font_spin), (double)fs);
    gtk_box_append(GTK_BOX(row2), st->font_spin);
    gtk_box_append(GTK_BOX(box), row2);

    GtkWidget *row3 = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_append(GTK_BOX(row3), gtk_label_new("Preferred Compositor:"));
    st->session_dd = gtk_drop_down_new_from_strings(SESSION_LABELS);
    char *cur_sess = get_key_or_default(kf, "general", "default_session", "hyprland");
    gtk_drop_down_set_selected(GTK_DROP_DOWN(st->session_dd), find_id_index(SESSION_IDS, 2, cur_sess));
    g_free(cur_sess);
    gtk_box_append(GTK_BOX(row3), st->session_dd);
    gtk_box_append(GTK_BOX(box), row3);

    GtkWidget *note = gtk_label_new(
        "Tip: Press F2 at login (greetd / tuigreet) to switch between Hyprland and Niri anytime.\n"
        "All themes use flat solid matte surfaces with zero wallpaper bloat for maximum performance."
    );
    gtk_label_set_xalign(GTK_LABEL(note), 0.0f);
    gtk_label_set_wrap(GTK_LABEL(note), TRUE);
    gtk_box_append(GTK_BOX(box), note);
    return box;
}

static GtkWidget *build_hotkeys_tab(SettingsState *st, GKeyFile *kf) {
    GtkWidget *scrolled = gtk_scrolled_window_new();
    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(grid), 16);
    gtk_grid_set_row_spacing(GTK_GRID(grid), 8);
    gtk_widget_set_margin_top(grid, 14);
    gtk_widget_set_margin_bottom(grid, 14);
    gtk_widget_set_margin_start(grid, 16);
    gtk_widget_set_margin_end(grid, 16);

    GtkWidget *h1 = gtk_label_new("Action");
    GtkWidget *h2 = gtk_label_new("Key (combined with Super)");
    gtk_label_set_xalign(GTK_LABEL(h1), 0.0f);
    gtk_label_set_xalign(GTK_LABEL(h2), 0.0f);
    gtk_grid_attach(GTK_GRID(grid), h1, 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), h2, 1, 0, 1, 1);

    for (size_t i = 0; i < NUM_HOTKEYS; ++i) {
        GtkWidget *lbl = gtk_label_new(HOTKEYS[i].label);
        gtk_label_set_xalign(GTK_LABEL(lbl), 0.0f);
        gtk_widget_set_hexpand(lbl, TRUE);

        GtkWidget *entry = gtk_entry_new();
        char *val = get_key_or_default(kf, "hotkeys", HOTKEYS[i].key, HOTKEYS[i].def_val);
        gtk_editable_set_text(GTK_EDITABLE(entry), val);
        g_free(val);
        gtk_editable_set_width_chars(GTK_EDITABLE(entry), 16);

        st->hotkey_entries[i] = entry;
        gtk_grid_attach(GTK_GRID(grid), lbl, 0, (int)(i + 1), 1, 1);
        gtk_grid_attach(GTK_GRID(grid), entry, 1, (int)(i + 1), 1, 1);
    }

    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), grid);
    return scrolled;
}

static GtkWidget *build_paths_tab(SettingsState *st, GKeyFile *kf) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_start(box, 16);
    gtk_widget_set_margin_end(box, 16);

    const char *home = g_get_home_dir();
    for (size_t i = 0; i < NUM_PATHS; ++i) {
        GtkWidget *lbl = gtk_label_new(PATHS[i].label);
        gtk_label_set_xalign(GTK_LABEL(lbl), 0.0f);
        gtk_box_append(GTK_BOX(box), lbl);

        char *def_full = g_build_filename(home, PATHS[i].def_val, NULL);
        char *val = get_key_or_default(kf, "paths", PATHS[i].key, def_full);
        g_free(def_full);

        GtkWidget *entry = gtk_entry_new();
        gtk_editable_set_text(GTK_EDITABLE(entry), val);
        gtk_widget_set_hexpand(entry, TRUE);
        g_free(val);

        st->path_entries[i] = entry;
        gtk_box_append(GTK_BOX(box), entry);
    }

    GtkWidget *hint = gtk_label_new(
        "Saving automatically syncs OBS Studio recording output, LocalSend download destination, and ~/SHORTCUTS.txt."
    );
    gtk_label_set_xalign(GTK_LABEL(hint), 0.0f);
    gtk_label_set_wrap(GTK_LABEL(hint), TRUE);
    gtk_box_append(GTK_BOX(box), hint);
    return box;
}

static GtkWidget *build_reset_tab(SettingsState *st) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    gtk_widget_set_margin_top(box, 16);
    gtk_widget_set_margin_start(box, 16);
    gtk_widget_set_margin_end(box, 16);

    char *storage_txt = read_storage_status();
    GtkWidget *storage_lbl = gtk_label_new(storage_txt);
    g_free(storage_txt);
    gtk_label_set_xalign(GTK_LABEL(storage_lbl), 0.0f);
    gtk_label_set_selectable(GTK_LABEL(storage_lbl), TRUE);
    gtk_box_append(GTK_BOX(box), storage_lbl);

    GtkWidget *wiz_btn = gtk_button_new_with_label("Open Project Stack Wizard (Install Languages)");
    g_signal_connect(wiz_btn, "clicked", G_CALLBACK(on_open_wizard), st);
    gtk_box_append(GTK_BOX(box), wiz_btn);

    gtk_box_append(GTK_BOX(box), gtk_separator_new(GTK_ORIENTATION_HORIZONTAL));

    GtkWidget *desc = gtk_label_new(
        "Project Reset Only:\n"
        "• Wipes ~/Projects, installed language toolchains, LazyVim language extras, and Firefox session caches.\n"
        "• Keeps Wi-Fi profiles, SSH keys (~/.ssh), Git config, and all OS settings (themes, hotkeys, export paths)."
    );
    gtk_label_set_xalign(GTK_LABEL(desc), 0.0f);
    gtk_label_set_wrap(GTK_LABEL(desc), TRUE);
    gtk_box_append(GTK_BOX(box), desc);

    GtkWidget *reset_btn = gtk_button_new_with_label("Reset Project Environment Now");
    gtk_widget_add_css_class(reset_btn, "destructive-action");
    g_signal_connect(reset_btn, "clicked", G_CALLBACK(on_reset_clicked), st);
    gtk_box_append(GTK_BOX(box), reset_btn);
    return box;
}

static void on_activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;
    SettingsState *st = g_new0(SettingsState, 1);

    const char *home = g_get_home_dir();
    st->settings_path = g_build_filename(home, ".config", "projects-os", "settings.conf", NULL);

    if (!g_file_test(st->settings_path, G_FILE_TEST_EXISTS)) {
        (void)system("/usr/local/bin/projects-apply-config");
    }

    GKeyFile *kf = g_key_file_new();
    g_key_file_load_from_file(kf, st->settings_path, G_KEY_FILE_NONE, NULL);

    st->win = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(st->win), "Projects OS Settings");
    gtk_window_set_default_size(GTK_WINDOW(st->win), 740, 560);

    GtkWidget *outer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_top(outer, 14);
    gtk_widget_set_margin_bottom(outer, 14);
    gtk_widget_set_margin_start(outer, 16);
    gtk_widget_set_margin_end(outer, 16);
    gtk_window_set_child(GTK_WINDOW(st->win), outer);

    GtkWidget *nb = gtk_notebook_new();
    gtk_widget_set_vexpand(nb, TRUE);
    gtk_notebook_append_page(GTK_NOTEBOOK(nb), build_appearance_tab(st, kf), gtk_label_new("Themes & UI"));
    gtk_notebook_append_page(GTK_NOTEBOOK(nb), build_hotkeys_tab(st, kf), gtk_label_new("Hotkeys"));
    gtk_notebook_append_page(GTK_NOTEBOOK(nb), build_paths_tab(st, kf), gtk_label_new("Data Export Paths"));
    gtk_notebook_append_page(GTK_NOTEBOOK(nb), build_reset_tab(st), gtk_label_new("Project Reset & System"));
    gtk_box_append(GTK_BOX(outer), nb);

    g_key_file_free(kf);

    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    st->status_lbl = gtk_label_new("");
    gtk_widget_set_hexpand(st->status_lbl, TRUE);
    gtk_label_set_xalign(GTK_LABEL(st->status_lbl), 0.0f);
    gtk_box_append(GTK_BOX(footer), st->status_lbl);

    GtkWidget *save_btn = gtk_button_new_with_label("Save & Apply Live");
    gtk_widget_add_css_class(save_btn, "suggested-action");
    g_signal_connect(save_btn, "clicked", G_CALLBACK(on_save_clicked), st);
    gtk_box_append(GTK_BOX(footer), save_btn);
    gtk_box_append(GTK_BOX(outer), footer);

    gtk_window_present(GTK_WINDOW(st->win));
}

int main(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("org.projectsos.settings", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
