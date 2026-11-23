# Kernel, early-boot drivers and flash-friendly runtime settings.
# Shared by the installed system (hosts/portable) and the live ISO (hosts/live).
{ pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ohci_pci"
      "uhci_hcd"
      "usbhid"
      "usb_storage"
      "uas"
      "sd_mod"
      "sr_mod"
      "ahci"
      "nvme"
      "vmd"
      "sdhci"
      "sdhci_pci"
      "mmc_block"
      "rtsx_pci_sdmmc"
      "rtsx_usb_sdmmc"
      "thunderbolt"
    ];

    # USB sticks can take a moment to enumerate.
    kernelParams = [
      "rootwait"
      "quiet"
      "loglevel=3"
    ];

    supportedFilesystems = [
      "ntfs"
      "exfat"
      "vfat"
    ];

    # Less writing to the stick.
    tmp = {
      useTmpfs = true;
      tmpfsSize = "25%";
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Logs live in RAM only.
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=64M
  '';
}
