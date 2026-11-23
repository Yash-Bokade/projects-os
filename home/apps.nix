{ pkgs, theme, ... }:
{
  home.packages = with pkgs; [
    swaybg
    swayidle
  ];

  # Screen recording / streaming.
  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-pipewire-audio-capture ];
  };

  # Notifications.
  services.mako = {
    enable = true;
    settings = {
      anchor = "top-right";
      font = "${theme.font} ${toString theme.fontSize}";
      background-color = theme.surface;
      text-color = theme.fg;
      border-color = theme.primary;
      border-size = 2;
      border-radius = 0;
      padding = "10";
      default-timeout = 4000;
    };
  };

  # Auto-mount USB drives and SD cards.
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never";
  };
}
