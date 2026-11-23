# ==========================================================================
#  nomad — system configuration (shared by every image this repo builds)
#  Everything global lives here: services, network, packages, login.
#  The live-ISO specifics (boot, persistence, rescue) are in iso.nix.
#  User-level apps and dotfiles are in home.nix.
# ==========================================================================
{
  config,
  pkgs,
  lib,
  inputs,
  username,
  hostname,
  timezone,
  locale,
  ...
}:
let
  # tiny helper binaries the niri session spawns (kept single-token so
  # swayidle can run them without a shell)
  lockscreen = pkgs.writeShellScriptBin "lockscreen" ''
    # screensaver = lock screen with the massive mono clock
    exec ${pkgs.swaylock-effects}/bin/swaylock
  '';
  screen-off = pkgs.writeShellScriptBin "screen-off" ''
    exec ${config.programs.niri.package}/bin/niri msg action power-off-monitors
  '';
in
{
  imports = [
    ./modules/mkproj.nix
  ];

  # ---- identity ----------------------------------------------------------
  networking.hostName = hostname;
  time.timeZone = timezone;
  i18n.defaultLocale = locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS = locale;
    LC_IDENTIFICATION = locale;
    LC_MEASUREMENT = locale;
    LC_MONETARY = locale;
    LC_NAME = locale;
    LC_NUMERIC = locale;
    LC_PAPER = locale;
    LC_TELEPHONE = locale;
    LC_TIME = locale;
  };

  # ---- user ---------------------------------------------------------------
  users.users.${username} = {
    isNormalUser = true;
    description = "nomad user";
    extraGroups = [
      "wheel"          # sudo
      "networkmanager" # manage wifi
      "video"
      "audio"
      "input"
      "storage"        # udisks / removable media
    ];
    initialPassword = "nomad"; # live system: resets to this on every boot
  };

  # ---- nix itself ---------------------------------------------------------
  nixpkgs.config.allowUnfree = true; # CPU microcode blobs
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  # projects resolve `nixpkgs` through this registry, so `nix develop`
  # inside ~/Projects works offline and always matches this OS's nixpkgs
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

  # ---- network ------------------------------------------------------------
  networking.networkmanager.enable = true;
  # LocalSend (send/receive files between phones and laptops)
  programs.localsend = {
    enable = true;
    openFirewall = true; # opens 53317/tcp + 53317/udp
  };

  # ---- desktop session (niri) ---------------------------------------------
  programs.niri.enable = true;
  programs.dconf.enable = true;
  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome   # screencast (OBS screen capture)
      pkgs.xdg-desktop-portal-gtk     # file chooser etc.
    ];
    config.common.default = [
      "gnome"
      "gtk"
    ];
  };

  # login: minimal terminal greeter, remembers your username
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${lib.getExe pkgs.tuigreet} --time --asterisks --remember --sessions ${config.programs.niri.package}/share/wayland-sessions";
      user = "greeter";
    };
  };
  # per niri wiki: without this, niri.service injects a stripped PATH that
  # shadows the one niri-session imported for the user
  systemd.user.services.niri.enableDefaultPath = false;

  # ---- audio (pipewire; OBS desktop audio depends on this) ----------------
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # ---- bluetooth -----------------------------------------------------------
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # ---- OBS Studio -----------------------------------------------------------
  programs.obs-studio.enable = true;

  # ---- fonts -----------------------------------------------------------------
  fonts.packages = with pkgs; [
    jetbrains-mono
    noto-fonts
  ];

  # ---- global environment ------------------------------------------------------
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # electron apps go native wayland
  };

  # ---- global packages ("installed once, available everywhere") ---------------
  environment.systemPackages =
    let
      libexec = "/run/current-system/sw/libexec";
    in
    with pkgs;
    [
      lockscreen
      screen-off

      # session tools
      ghostty # terminal (transparent, mono theme)
      waybar
      fuzzel
      swaylock-effects # the big-clock screensaver / locker
      swaybg
      swayidle
      brightnessctl

      # settings applets (live in the waybar tray)
      networkmanagerapplet # wifi: nm-applet + nm-connection-editor
      blueman # bluetooth: blueman-applet + blueman-manager
      polkit_gnome # password prompts for privileged actions

      # device manager stack
      usbview # GUI: usb device tree
      gnome-disk-utility # GUI: disks, partitions, health
      lshw # CLI: full hardware listing (sudo lshw)
      pciutils # lspci
      usbutils # lsusb
      # hardinfo2  # system info GUI — currently marked broken in nixpkgs;
      #            # uncomment when upstream fixes it

      # audio / media
      pavucontrol
      playerctl

      # dev essentials (global — installed once)
      beamPackages.elixir # mix available system-wide (plain pkgs.elixir is deprecated)
      git
      direnv
      nano
      wget
      curl
      htop
      wl-clipboard
      unzip
      zip
      file
    ];

  # ---- hardware tuned for travel ---------------------------------------------
  hardware.enableRedistributableFirmware = true; # wifi/bt firmware for many chips
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.graphics.enable = true;

  # /tmp in RAM: fewer writes to the flash chip
  boot.tmp.useTmpfs = true;

  # swap in RAM (zstd-compressed) instead of wearing out the stick
  swapDevices = [ ];
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ---- housekeeping tuned for flash storage ------------------------------------
  # logs live in RAM only: nothing hammers the stick at runtime
  services.journald.settings.Journal = {
    Storage = "volatile";
    SystemMaxUse = "200M";
  };
  documentation.nixos.enable = false; # skip the huge generated option docs
  programs.command-not-found.enable = false;

  system.stateVersion = "25.05";
}
