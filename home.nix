# ==========================================================================
#  nomad — home-manager: user apps and dotfiles
#
#  App binaries (ghostty, waybar, fuzzel, swaylock-effects, ...) are
#  installed globally in shared.nix — "installed once, usable
#  everywhere". This file manages per-user configuration and apps that
#  need profile wiring (firefox policies, direnv, gtk, bash).
# ==========================================================================
{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # ---- window manager / terminal / bar / launcher / screensaver configs ----
  # niri config is validated during the build (niri validate) — a broken
  # config fails the rebuild instead of breaking the session.
  xdg.configFile."niri/config.kdl".source = pkgs.runCommand "niri-config-checked"
    {
      nativeBuildInputs = [ pkgs.niri ];
    }
    ''
      niri validate --config ${./files/niri.kdl}
      cp ${./files/niri.kdl} $out
    '';

  xdg.configFile."ghostty/config".source = ./files/ghostty.conf;
  xdg.configFile."waybar/config".source = ./files/waybar.json;
  xdg.configFile."waybar/style.css".source = ./files/waybar.css;
  xdg.configFile."fuzzel/fuzzel.ini".source = ./files/fuzzel.ini;
  xdg.configFile."swaylock/config".source = ./files/swaylock.conf;

  # ---- firefox, minimal edition --------------------------------------------
  # telemetry off, pocket off, studies off, no account nag, blank new tab,
  # https-only. Everything else stays lean.
  programs.firefox = {
    enable = true;
    # adopt the XDG profile location (home-manager's new default)
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles.default = { };
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;
      DisableFirefoxAccounts = true;
      DisableProfileImport = true;
      NoDefaultBrowserCheck = true;
      SearchSuggestEnabled = false;
      Preferences = {
        "browser.newtabpage.enabled" = { Value = false; Status = "locked"; };
        "browser.startup.homepage" = { Value = "about:blank"; Status = "default"; };
        "browser.shell.checkDefaultBrowser" = { Value = false; Status = "locked"; };
        "browser.aboutConfig.showWarning" = { Value = false; Status = "locked"; };
        "dom.security.https_only_mode" = { Value = true; Status = "locked"; };
        "signon.rememberSignons" = { Value = true; Status = "default"; };
      };
    };
  };

  # ---- direnv + nix-direnv: `cd ~/Projects/<name>` auto-enters the dev shell --
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ---- git (identity is set per-project by `mkproj`) --------------------------
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      core.editor = "nano";
    };
  };

  # ---- mono gtk theme -----------------------------------------------------------
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    # keep non-libadwaita GTK4 apps dark too (adw-gtk3 ships a GTK4 variant)
    gtk4.theme = config.gtk.theme;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  # ---- shell ----------------------------------------------------------------------
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      projects = "cd ~/Projects";
      # live-test config edits: clone your fork of this repo to ~/nomad,
      # edit, then run `rebuild` (new packages need network; they live in
      # RAM until the next ISO build, unless you persist /nix yourself)
      rebuild = "sudo nixos-rebuild test --flake ~/nomad#nomad-iso";
    };
    bashrcExtra = ''
      # mono prompt: dim path, NixOS-blue arrow
      PS1='\[\e[90m\]\w\[\e[0m\] \[\e[38;2;82;119;195m\]❯\[\e[0m\] '
    '';
  };

  home.sessionVariables = {
    EDITOR = "nano";
    VISUAL = "nano";
  };

  # keep the home dir tidy and predictable
  home.file.".config/README".text = ''
    dotfiles on this system are managed by home-manager
    (they come from the nomad repo this ISO was built from)
  '';
}
