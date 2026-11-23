# Boot loader for the INSTALLED system: boots on (almost) any UEFI machine from USB / SD.
# (The live ISO has its own boot loader from nixpkgs' iso-image.nix.)
{ ... }:
{
  boot.loader = {
    timeout = 2;
    efi = {
      # A portable OS must NOT touch the host machine's NVRAM boot entries.
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
    grub = {
      enable = true;
      efiSupport = true;
      # Installs to /EFI/BOOT/BOOTX64.EFI, the fallback path every UEFI firmware knows.
      efiInstallAsRemovable = true;
      device = "nodev";
      configurationLimit = 5;
    };
  };
}
