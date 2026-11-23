# System-wide packages. Rust is pre-installed here.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Rust toolchain
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    gcc
    pkg-config

    # Nix tooling
    nil
    nixfmt

    # Core CLI
    git
    curl
    wget
    jq
    ripgrep
    fd
    unzip
    zip
    btop
    tree

    # Disks and hardware ("device manager")
    pciutils
    usbutils
    parted
    gptfdisk
    e2fsprogs
    dosfstools
    gnome-disk-utility

    # Desktop helpers
    pavucontrol
    brightnessctl
    wl-clipboard
    libnotify
    xwayland-satellite # X11 apps under niri
  ];
}
