{ theme, ... }:
{
  programs.zed-editor = {
    enable = true;
    # Fetched by Zed on first launch (needs network once, then cached in /home).
    extensions = [
      "nix"
      "toml"
    ];

    userSettings = {
      theme = {
        mode = "dark";
        dark = "One Dark";
        light = "One Dark";
      };
      ui_font_family = theme.font;
      buffer_font_family = theme.font;
      buffer_font_size = 14;
      ui_font_size = 14;
      tab_size = 4;
      autosave = "on_focus_change";
      format_on_save = "on";
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      terminal.font_family = theme.font;
      git.inline_blame.enabled = false;

      languages.Nix = {
        language_servers = [ "nil" ];
        formatter.external.command = "nixfmt";
      };

      # Same palette as the rest of the desktop.
      "experimental.theme_overrides" = {
        "background" = theme.surface;
        "editor.background" = theme.surface;
        "editor.gutter.background" = theme.surface;
        "terminal.background" = theme.surface;
        "border" = theme.border;
        "border.focused" = theme.primary;
        "text.accent" = theme.primary;
        "element.selected" = theme.surfaceAlt;
        "tab.active_background" = theme.surfaceAlt;
      };
    };
  };
}
