# Custom commands: mkproj, devmgr, powermenu, desktop-start, screensaver-preview.
{ pkgs, lib, theme, ... }:
let
  # Wrap a script file so its dependencies are on PATH no matter where it runs from.
  mk =
    name: deps: file:
    pkgs.writeShellScriptBin name ''
      export PATH=${lib.makeBinPath deps}:$PATH
      ${builtins.readFile file}
    '';
in
{
  home.packages = [
    # Create a project: npm-init style prompts, git init, flake.nix, .envrc ...
    (mk "mkproj" [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.gnused
      pkgs.gnugrep
      pkgs.direnv
      pkgs.nix
      pkgs.cargo
    ] ./scripts/mkproj.sh)

    # rofi device manager: mount / unmount / eject drives, show PCI + USB hardware.
    (mk "devmgr" [
      pkgs.coreutils
      pkgs.rofi
      pkgs.util-linux
      pkgs.jq
      pkgs.udisks
      pkgs.libnotify
      pkgs.pciutils
      pkgs.usbutils
      pkgs.ghostty
      pkgs.bash
    ] ./scripts/devmgr.sh)

    (mk "powermenu" [
      pkgs.coreutils
      pkgs.rofi
      pkgs.systemd
      pkgs.niri
    ] ./scripts/powermenu.sh)

    # Wallpaper first, widgets second: both live on the background layer and the
    # later one is drawn on top.
    (pkgs.writeShellScriptBin "desktop-start" ''
      export PATH=${
        lib.makeBinPath [
          pkgs.swaybg
          pkgs.eww
          pkgs.coreutils
        ]
      }:$PATH
      swaybg -c "${theme.wallpaper}" -m solid_color &
      sleep 1
      eww daemon
      sleep 1
      eww open-many clock system
    '')

    # Try the screensaver for 8 seconds without waiting for idle.
    (pkgs.writeShellScriptBin "screensaver-preview" ''
      export PATH=${
        lib.makeBinPath [
          pkgs.eww
          pkgs.coreutils
        ]
      }:$PATH
      eww open screensaver
      sleep 8
      eww close screensaver
    '')
  ];
}
