# The LIVE ISO (built by GitHub Actions): the same desktop, booted from the stick.
# On first boot a service turns the free space on the stick into a PERSIST partition
# and mounts it as /home (see modules/system/persist-live.nix).
{
  lib,
  vars,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/all-hardware.nix"
    ../common/home.nix
    ../../modules/system/kernel.nix
    ../../modules/system/hardware.nix
    ../../modules/system/nix.nix
    ../../modules/system/network.nix
    ../../modules/system/audio.nix
    ../../modules/system/desktop.nix
    ../../modules/system/users.nix
    ../../modules/system/packages.nix
    ../../modules/system/slim.nix
    ../../modules/system/persist-live.nix
  ];

  isoImage = {
    isoName = "portable-nixos.iso";
    volumeID = vars.isoLabel;
    makeEfiBootable = true;
    makeUsbBootable = true;
    # Smaller image = fewer release parts. Costs build time on the runner, not boot time.
    squashfsCompression = "zstd -Xcompression-level 19";
  };

  # Log in automatically on the live system, and let the user sudo without a password.
  services.greetd.settings.initial_session = {
    command = "niri-session";
    user = vars.user;
  };
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # Do not start the session before /home is mounted and Home Manager has written the config.
  systemd.services.greetd = {
    after = [
      "persist-setup.service"
      "home-manager-${vars.user}.service"
    ];
    wants = [ "home-manager-${vars.user}.service" ];
  };

  system.stateVersion = "26.05";
}
