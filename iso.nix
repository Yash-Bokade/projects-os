# ==========================================================================
#  nomad — the bootable live ISO (what GitHub Actions builds)
#
#  The system runs from RAM (read-only squashfs + tmpfs overlay for the
#  nix store). Two things make it usable as a daily machine:
#
#  1. persistence: after `sudo persist-setup` creates a btrfs partition
#     labeled "persist" in the stick's free space, impermanence binds
#     /home and your state (wifi passwords, bluetooth pairings, machine
#     id, uid map) into every boot. Everything else is ephemeral —
#     packages are baked into the ISO instead.
#  2. rescue: the installer profile this image is built on ships a full
#     hardware stack (enableAllHardware) plus disk tools, so the stick
#     doubles as a repair USB for any machine.
#
#  The installer defaults this file overrides are listed below with a
#  short "why" each time. `mkForce` is needed because the installer
#  profile raises its settings above normal priority (mkImageMediaOverride).
# ==========================================================================
{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  ...
}:
let
  persist-setup = pkgs.writeShellScriptBin "persist-setup" (
    builtins.readFile ./scripts/persist-setup.sh
  );
in
{
  imports = [
    # the full live-CD machinery: squashfs store, overlay root, hybrid
    # BIOS+UEFI GRUB, copytoram support, generic hardware profile
    (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
  ];

  # ---- the image itself -----------------------------------------------------
  isoImage = {
    # the ISO is found by this label at boot — A-Z0-9_, max 32 chars
    volumeID = "NIXOS_NOMAD";
    # zstd-6 builds ~4x faster than the zstd-19 default; boots the same
    squashfsCompression = "zstd -Xcompression-level 6";
  };
  boot.loader.timeout = lib.mkForce 3; # installer default is 10
  # Memtest86+ is a nice installer extra, not needed on a pocket stick
  boot.loader.grub.memtest86.enable = lib.mkForce false;

  # ---- turn "installation CD" into "pocket OS" -------------------------------
  # greetd owns tty1; no autologin on any console
  services.getty.autologinUser = lib.mkForce null;
  # a login hint instead of the installer's text (it mentions accounts
  # that are locked below)
  services.getty.helpLine = lib.mkForce ''

      Log in on the greeter as `dev` (password: nomad).
      WiFi: `nmtui` after logging in.   Persistence: `sudo persist-setup`.
  '';
  # the installer's passwordless nixos/root accounts stay but are locked;
  # `dev` is the only way in (it is in wheel for sudo with your password)
  users.users.nixos.initialHashedPassword = lib.mkForce "*";
  users.users.root.initialHashedPassword = lib.mkForce "*";
  # the installer profile gives wheel passwordless sudo — no thank you
  security.sudo.wheelNeedsPassword = lib.mkForce true;
  # no ssh server on a stick you carry around hotels
  services.openssh.enable = lib.mkForce false;
  # don't ship the generated NixOS manual (several hundred MB)
  documentation.nixos.enable = lib.mkForce false;
  # don't bundle the nixpkgs channel tarball (~300 MB). nixpkgs resolves
  # through the baked-in flake registry (see shared.nix) instead — offline
  # too, because the registry points into the ISO's own store
  system.installer.channel.enable = false;
  # zfs is the heaviest module set and the persist volume is btrfs
  boot.supportedFilesystems.zfs = lib.mkForce false;
  # the squashfs store is read-only; garbage collecting it is pointless
  nix.gc.automatic = lib.mkForce false;
  # let the user run nix against the system store without warnings
  nix.settings.trusted-users = [ username ];

  # ---- persistence -----------------------------------------------------------
  # mounts once `persist-setup` has created the partition; `nofail` keeps
  # boots working before that (everything is simply ephemeral then).
  # neededForBoot mounts it in the initrd, so impermanence's bind units
  # can never race against it (upstream's recommended setup).
  #
  # NOTE on priorities: the installer profile replaces the whole
  # `fileSystems` option with `mkImageMediaOverride` (priority 60), which
  # discards any nested per-mount definitions regardless of their
  # priority. Declaring the extra mount at the option's top level with
  # the SAME priority is what makes it merge alongside the ISO's mounts.
  fileSystems = lib.mkImageMediaOverride {
    "/persist" = {
      device = "/dev/disk/by-label/persist";
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "compress=zstd"
        "noatime"
        "nofail"
        "x-systemd.device-timeout=5s"
      ];
    };
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/home" # projects, dotfiles, browser profile, everything personal
      "/etc/NetworkManager/system-connections" # saved wifi passwords
      "/var/lib/NetworkManager" # leases, connection timestamps
      "/var/lib/bluetooth" # paired devices
      "/var/lib/nixos" # uid/gid map — keeps file ownership stable
    ];
    files = [
      "/etc/machine-id" # stable identity (LocalSend, journald, dbus)
    ];
  };

  # ---- tools for the persist-setup flow ---------------------------------------
  environment.systemPackages = [
    persist-setup
    pkgs.btrfs-progs # format + inspect the persist volume
  ];

  # ---- a note in the home dir until persistence is set up --------------------
  # persist-setup removes it after a successful setup
  home-manager.users.${username}.home.file."PERSISTENCE.txt".text = ''
    this system is live: it runs from RAM and resets on every reboot.

    projects, dotfiles, wifi passwords and bluetooth pairings survive
    on the stick only after you enable persistence once:

        sudo persist-setup

    it takes the free space at the end of the stick (about 20+ GB on a
    28 GB drive), creates the persistent partition, copies your current
    home onto it and rebinds everything on every boot. after that this
    file disappears.

    until then, anything you save outside /persist is gone on reboot.
  '';
}
