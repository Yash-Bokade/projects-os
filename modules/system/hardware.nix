# Generic hardware support so the same stick boots on many different machines.
{ pkgs, ... }:
{
  # Wi-Fi / Bluetooth / GPU firmware for as many machines as possible (~1 GB).
  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    extraPackages = [
      pkgs.intel-media-driver
      pkgs.libvdpau-va-gl
    ];
  };

  services.upower.enable = true; # battery info for waybar
  services.udisks2.enable = true; # mount / unmount USB drives without root
  services.gvfs.enable = true;
  powerManagement.enable = true;
}
