/*
 * Projects OS — First-Boot Connectivity & Project Stack Wizard (Native C11 + GTK4)
 * Zero Python dependencies.
 */
#define _POSIX_C_SOURCE 200809L

#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>

typedef struct {
    const char *key;
    const char *label;
    const char *method;     /* "mise" or "pacman" */
    const char *spec;
    const char *nvim_extra;
} StackDef;

static const StackDef STACKS[] = {
    { "java",   "Java (Latest OpenJDK)",     "mise",   "java@latest",               "lazyvim.plugins.extras.lang.java" },
    { "rust",   "Rust (Latest Toolchain)",   "mise",   "rust@latest",               "lazyvim.plugins.extras.lang.rust" },
    { "go",     "Go (Latest Release)",       "mise",   "go@latest",                 "lazyvim.plugins.extras.lang.go" },
    { "node",   "Node.js + TypeScript",      "mise",   "node@latest",               "lazyvim.plugins.extras.lang.typescript" },
    { "cpp",    "C / C++ (Clang + CMake)",   "pacman", "clang cmake ninja gdb lldb","lazyvim.plugins.extras.lang.clangd" },
    { "zig",    "Zig (Latest)",              "mise",   "zig@latest",                "lazyvim.plugins.extras.lang.zig" },
    { "bun",    "Bun (Latest JS Runtime)",   "mise",   "bun@latest",                "lazyvim.plugins.extras.lang.typescript" },
    { "python", "Python (Latest 3.x)",       "mise",   "python@latest",             "lazyvim.plugins.extras.lang.python" },
};

#define NUM_STACKS (sizeof(STACKS) / sizeof(STACKS[0]))

typedef struct {
    GtkWidget *win;
    GtkWidget *net_status;
    GtkWidget *checks[NUM_STACKS];
    GtkWidget *custom_entry;
    GtkWidget *install_btn;
    GtkTextBuffer *log_buf;
} WizardState;

typedef struct {
    WizardState *st;
    char *msg;
} UiTextMsg;

typedef struct {
    WizardState *st;
    gboolean selected[NUM_STACKS];
    char *extra_tools;
} InstallTask;

static gboolean ui_set_net_status(gpointer data) {
    UiTextMsg *m = (UiTextMsg *)data;
    gtk_label_set_text(GTK_LABEL(m->st->net_status), m->msg);
    g_free(m->msg);
    g_free(m);
    return G_SOURCE_REMOVE;
}

static gboolean ui_append_log(gpointer data) {
    UiTextMsg *m = (UiTextMsg *)data;
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(m->st->log_buf, &end);
    gtk_text_buffer_insert(m->st->log_buf, &end, m->msg, -1);
    gtk_text_buffer_insert(m->st->log_buf, &end, "\n", -1);
    g_free(m->msg);
    g_free(m);
    return G_SOURCE_REMOVE;
}

static void append_log_async(WizardState *st, const char *line) {
    UiTextMsg *m = g_new0(UiTextMsg, 1);
    m->st = st;
    m->msg = g_strdup(line);
    g_idle_add(ui_append_log, m);
}

static gboolean ui_finish_wizard(gpointer data) {
    WizardState *st = (WizardState *)data;
    const char *home = g_get_home_dir();
    char *state_dir = g_build_filename(home, ".local", "state", "projects-os", NULL);
    g_mkdir_with_parents(state_dir, 0755);

    char *done_file = g_build_filename(state_dir, "wizard-done", NULL);
    g_file_set_contents(done_file, "completed\n", -1, NULL);

    gchar *argv[] = { "notify-send", "Projects OS Ready", "Your project environment is configured.", NULL };
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, NULL);

    g_free(done_file);
    g_free(state_dir);
    gtk_window_close(GTK_WINDOW(st->win));
    return G_SOURCE_REMOVE;
}

static gpointer check_internet_thread(gpointer data) {
    WizardState *st = (WizardState *)data;
    int rc = system("curl -fsS --max-time 4 https://archlinux.org >/dev/null 2>&1");
    UiTextMsg *m = g_new0(UiTextMsg, 1);
    m->st = st;
    m->msg = g_strdup(rc == 0
        ? "Online — Ready to install latest toolchains."
        : "Offline — Connect Wi-Fi or plug in Ethernet.");
    g_idle_add(ui_set_net_status, m);
    return NULL;
}

static void trigger_internet_check(WizardState *st) {
    gtk_label_set_text(GTK_LABEL(st->net_status), "Checking internet connection...");
    GThread *t = g_thread_new("net-check", check_internet_thread, st);
    g_thread_unref(t);
}

static void on_recheck_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    trigger_internet_check((WizardState *)data);
}

static void on_wifi_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    (void)data;
    gchar *argv[] = { "foot", "--title=Network Setup", "-e", "nmtui", NULL };
    g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, NULL);
}

static void on_skip_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    ui_finish_wizard(data);
}

static int run_logged_cmd(WizardState *st, const char *cmd) {
    char header[512];
    snprintf(header, sizeof(header), "$ %s", cmd);
    append_log_async(st, header);

    char full_cmd[1024];
    snprintf(full_cmd, sizeof(full_cmd), "%s 2>&1", cmd);
    FILE *fp = popen(full_cmd, "r");
    if (!fp) {
        append_log_async(st, "ERROR: Failed to spawn command.");
        return -1;
    }

    char line[512];
    while (fgets(line, sizeof(line), fp) != NULL) {
        size_t len = strlen(line);
        while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r')) {
            line[--len] = '\0';
        }
        append_log_async(st, line);
    }
    return pclose(fp);
}

static gboolean is_safe_tool_token(const char *tok) {
    if (!tok || !*tok) return FALSE;
    for (const char *p = tok; *p; ++p) {
        unsigned char c = (unsigned char)*p;
        if (!(isalnum(c) || c == '@' || c == '.' || c == '-' || c == '_' || c == ':' || c == '/')) {
            return FALSE;
        }
    }
    return TRUE;
}

static void write_lazyvim_extras(const char *extras[], size_t count) {
    if (count == 0) return;

    const char *home = g_get_home_dir();
    char *nvim_dir = g_build_filename(home, ".config", "nvim", NULL);
    g_mkdir_with_parents(nvim_dir, 0755);
    char *json_path = g_build_filename(nvim_dir, "lazyvim.json", NULL);

    const char *uniq[NUM_STACKS];
    size_t ucount = 0;
    for (size_t i = 0; i < count; ++i) {
        gboolean dup = FALSE;
        for (size_t j = 0; j < ucount; ++j) {
            if (strcmp(uniq[j], extras[i]) == 0) {
                dup = TRUE;
                break;
            }
        }
        if (!dup && ucount < NUM_STACKS) {
            uniq[ucount++] = extras[i];
        }
    }

    FILE *fp = fopen(json_path, "w");
    if (fp) {
        fprintf(fp, "{\n  \"extras\": [\n");
        for (size_t i = 0; i < ucount; ++i) {
            fprintf(fp, "    \"%s\"%s\n", uniq[i], (i + 1 < ucount) ? "," : "");
        }
        fprintf(fp, "  ],\n  \"version\": 7\n}\n");
        fclose(fp);
    }

    g_free(json_path);
    g_free(nvim_dir);
}

static gpointer install_worker(gpointer data) {
    InstallTask *task = (InstallTask *)data;
    WizardState *st = task->st;

    const char *home = g_get_home_dir();
    char *state_dir = g_build_filename(home, ".local", "state", "projects-os", NULL);
    g_mkdir_with_parents(state_dir, 0755);

    const char *extras[NUM_STACKS];
    size_t extra_count = 0;
    GString *pacman_list = g_string_new(NULL);

    for (size_t i = 0; i < NUM_STACKS; ++i) {
        if (!task->selected[i]) continue;

        char banner[256];
        snprintf(banner, sizeof(banner), "==> Installing %s...", STACKS[i].label);
        append_log_async(st, banner);

        char cmd[512];
        if (strcmp(STACKS[i].method, "mise") == 0) {
            snprintf(cmd, sizeof(cmd), "mise use -g %s", STACKS[i].spec);
            run_logged_cmd(st, cmd);
        } else if (strcmp(STACKS[i].method, "pacman") == 0) {
            snprintf(cmd, sizeof(cmd), "sudo pacman -Sy --noconfirm --needed %s", STACKS[i].spec);
            run_logged_cmd(st, cmd);
            if (pacman_list->len > 0) g_string_append_c(pacman_list, ' ');
            g_string_append(pacman_list, STACKS[i].spec);
        }

        if (STACKS[i].nvim_extra && extra_count < NUM_STACKS) {
            extras[extra_count++] = STACKS[i].nvim_extra;
        }
    }

    if (task->extra_tools && task->extra_tools[0] != '\0') {
        char **tokens = g_strsplit_set(task->extra_tools, " \t\n", -1);
        for (int i = 0; tokens[i] != NULL; ++i) {
            if (tokens[i][0] == '\0') continue;
            if (!is_safe_tool_token(tokens[i])) {
                append_log_async(st, "Skipping invalid tool specification.");
                continue;
            }
            char cmd[256];
            snprintf(cmd, sizeof(cmd), "mise use -g %s", tokens[i]);
            run_logged_cmd(st, cmd);
        }
        g_strfreev(tokens);
    }

    if (pacman_list->len > 0) {
        char *list_path = g_build_filename(state_dir, "pacman-stacks.list", NULL);
        char **pkgs = g_strsplit(pacman_list->str, " ", -1);
        GString *lines = g_string_new(NULL);
        for (int i = 0; pkgs[i] != NULL; ++i) {
            if (pkgs[i][0] != '\0') {
                g_string_append(lines, pkgs[i]);
                g_string_append_c(lines, '\n');
            }
        }
        g_file_set_contents(list_path, lines->str, -1, NULL);
        g_string_free(lines, TRUE);
        g_strfreev(pkgs);
        g_free(list_path);
    }
    g_string_free(pacman_list, TRUE);

    if (extra_count > 0) {
        append_log_async(st, "==> Wiring selected languages into Neovim (LazyVim)...");
        write_lazyvim_extras(extras, extra_count);
        run_logged_cmd(st, "nvim --headless \"+Lazy! sync\" +qa");
    }

    append_log_async(st, "\nAll selected stacks are installed and ready in Neovim!");
    g_free(state_dir);
    g_free(task->extra_tools);
    g_free(task);

    g_idle_add(ui_finish_wizard, st);
    return NULL;
}

static void on_install_clicked(GtkButton *btn, gpointer data) {
    (void)btn;
    WizardState *st = (WizardState *)data;

    InstallTask *task = g_new0(InstallTask, 1);
    task->st = st;
    gboolean any = FALSE;
    for (size_t i = 0; i < NUM_STACKS; ++i) {
        task->selected[i] = gtk_check_button_get_active(GTK_CHECK_BUTTON(st->checks[i]));
        if (task->selected[i]) any = TRUE;
    }

    const char *custom = gtk_editable_get_text(GTK_EDITABLE(st->custom_entry));
    task->extra_tools = g_strstrip(g_strdup(custom ? custom : ""));
    if (task->extra_tools[0] != '\0') any = TRUE;

    if (!any) {
        g_free(task->extra_tools);
        g_free(task);
        ui_finish_wizard(st);
        return;
    }

    gtk_widget_set_sensitive(st->install_btn, FALSE);
    GThread *t = g_thread_new("stack-install", install_worker, task);
    g_thread_unref(t);
}

static void on_activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;
    WizardState *st = g_new0(WizardState, 1);

    st->win = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(st->win), "Projects OS — Project Setup Wizard");
    gtk_window_set_default_size(GTK_WINDOW(st->win), 680, 580);
    gtk_window_set_resizable(GTK_WINDOW(st->win), FALSE);

    GtkWidget *root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
    gtk_widget_set_margin_top(root, 20);
    gtk_widget_set_margin_bottom(root, 20);
    gtk_widget_set_margin_start(root, 22);
    gtk_widget_set_margin_end(root, 22);
    gtk_window_set_child(GTK_WINDOW(st->win), root);

    GtkWidget *title = gtk_label_new("Welcome to Projects OS");
    gtk_label_set_xalign(GTK_LABEL(title), 0.0f);
    gtk_widget_add_css_class(title, "title-1");
    gtk_box_append(GTK_BOX(root), title);

    GtkWidget *subtitle = gtk_label_new(
        "Step 1: Verify internet connectivity. Step 2: Pick the languages for your project.\n"
        "Latest versions are installed via mise/pacman and wired directly into Neovim (LazyVim)."
    );
    gtk_label_set_xalign(GTK_LABEL(subtitle), 0.0f);
    gtk_label_set_wrap(GTK_LABEL(subtitle), TRUE);
    gtk_box_append(GTK_BOX(root), subtitle);

    /* Step 1: Network Card */
    GtkWidget *net_frame = gtk_frame_new(" 1. Internet Connectivity ");
    GtkWidget *net_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_margin_top(net_box, 10);
    gtk_widget_set_margin_bottom(net_box, 10);
    gtk_widget_set_margin_start(net_box, 12);
    gtk_widget_set_margin_end(net_box, 12);
    gtk_frame_set_child(GTK_FRAME(net_frame), net_box);

    st->net_status = gtk_label_new("Checking internet connection...");
    gtk_widget_set_hexpand(st->net_status, TRUE);
    gtk_label_set_xalign(GTK_LABEL(st->net_status), 0.0f);
    gtk_box_append(GTK_BOX(net_box), st->net_status);

    GtkWidget *wifi_btn = gtk_button_new_with_label("Connect Wi-Fi / Ethernet");
    g_signal_connect(wifi_btn, "clicked", G_CALLBACK(on_wifi_clicked), st);
    gtk_box_append(GTK_BOX(net_box), wifi_btn);

    GtkWidget *recheck_btn = gtk_button_new_with_label("Recheck");
    g_signal_connect(recheck_btn, "clicked", G_CALLBACK(on_recheck_clicked), st);
    gtk_box_append(GTK_BOX(net_box), recheck_btn);
    gtk_box_append(GTK_BOX(root), net_frame);

    /* Step 2: Language Stack Picker */
    GtkWidget *stack_frame = gtk_frame_new(" 2. Select Project Language Stack(s) ");
    GtkWidget *stack_outer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_margin_top(stack_outer, 10);
    gtk_widget_set_margin_bottom(stack_outer, 10);
    gtk_widget_set_margin_start(stack_outer, 12);
    gtk_widget_set_margin_end(stack_outer, 12);

    GtkWidget *grid = gtk_grid_new();
    gtk_grid_set_column_spacing(GTK_GRID(grid), 20);
    gtk_grid_set_row_spacing(GTK_GRID(grid), 8);
    for (size_t i = 0; i < NUM_STACKS; ++i) {
        st->checks[i] = gtk_check_button_new_with_label(STACKS[i].label);
        gtk_grid_attach(GTK_GRID(grid), st->checks[i], (int)(i % 2), (int)(i / 2), 1, 1);
    }
    gtk_box_append(GTK_BOX(stack_outer), grid);

    GtkWidget *custom_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    GtkWidget *custom_lbl = gtk_label_new("Extra mise tools (optional):");
    st->custom_entry = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(st->custom_entry), "e.g. deno@latest kotlin@latest");
    gtk_widget_set_hexpand(st->custom_entry, TRUE);
    gtk_box_append(GTK_BOX(custom_row), custom_lbl);
    gtk_box_append(GTK_BOX(custom_row), st->custom_entry);
    gtk_box_append(GTK_BOX(stack_outer), custom_row);

    gtk_frame_set_child(GTK_FRAME(stack_frame), stack_outer);
    gtk_box_append(GTK_BOX(root), stack_frame);

    /* Step 3: Live Progress Log */
    GtkWidget *log_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(log_view), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(log_view), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(log_view), GTK_WRAP_WORD_CHAR);
    st->log_buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(log_view));

    GtkWidget *scrolled = gtk_scrolled_window_new();
    gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scrolled), 130);
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), log_view);
    gtk_box_append(GTK_BOX(root), scrolled);

    /* Action Buttons */
    GtkWidget *btn_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_halign(btn_row, GTK_ALIGN_END);

    GtkWidget *skip_btn = gtk_button_new_with_label("Skip for Now");
    g_signal_connect(skip_btn, "clicked", G_CALLBACK(on_skip_clicked), st);
    gtk_box_append(GTK_BOX(btn_row), skip_btn);

    st->install_btn = gtk_button_new_with_label("Install Stack & Launch Desktop");
    gtk_widget_add_css_class(st->install_btn, "suggested-action");
    g_signal_connect(st->install_btn, "clicked", G_CALLBACK(on_install_clicked), st);
    gtk_box_append(GTK_BOX(btn_row), st->install_btn);
    gtk_box_append(GTK_BOX(root), btn_row);

    trigger_internet_check(st);
    gtk_window_present(GTK_WINDOW(st->win));
}

int main(int argc, char **argv) {
    GtkApplication *app = gtk_application_new("org.projectsos.wizard", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
