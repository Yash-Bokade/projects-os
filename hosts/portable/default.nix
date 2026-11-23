# The INSTALLED portable system (scripts/install.sh): OS on NIXROOT, /home on PERSIST.
{ ... }:
{
  imports = [
    ../common/home.nix
    ../../modules/system/kernel.nix
    ../../modules/system/boot.nix
    ../../modules/system/storage.nix
    ../../modules/system/hardware.nix
    ../../modules/system/nix.nix
    ../../modules/system/network.nix
    ../../modules/system/audio.nix
    ../../modules/system/desktop.nix
    ../../modules/system/users.nix
    ../../modules/system/packages.nix
    ../../modules/system/slim.nix
  ];

  system.stateVersion = "26.05";
}
