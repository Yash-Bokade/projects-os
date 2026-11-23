{ pkgs, ... }:
{
  imports = [
    ./niri.nix
    ./ghostty.nix
    ./rofi.nix
    ./waybar.nix
    ./eww.nix
    ./firefox.nix
    ./zed.nix
    ./shell.nix
    ./apps.nix
    ./gtk.nix
    ./scripts.nix
  ];

  home = {
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "zeditor --wait";
      RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    };
  };

  programs.home-manager.enable = true;
}
