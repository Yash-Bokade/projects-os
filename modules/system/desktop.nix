# Wayland session: niri, greetd login screen, portals (screen capture for OBS), fonts.
{ pkgs, theme, ... }:
{
  programs.niri.enable = true;
  programs.dconf.enable = true;
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --theme 'border=yellow;text=white;prompt=yellow;time=yellow;action=yellow;button=yellow;container=black;input=white' --cmd niri-session";
      user = "greeter";
    };
  };

  # Screen sharing / recording (OBS) goes through these portals.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  fonts = {
    packages = [
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.noto-fonts
      pkgs.noto-fonts-color-emoji
      pkgs.liberation_ttf
    ];
    fontconfig.defaultFonts = {
      monospace = [ theme.font ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
