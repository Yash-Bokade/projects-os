# Three partitions, found by LABEL so the stick works on any machine / port.
# scripts/install.sh creates them.
#
#   NIXBOOT  512M  FAT32  EFI system partition
#   NIXROOT  28G   ext4   / and /nix  (the OS: kernel, store, system generations)
#   PERSIST  rest  ext4   /home       (projects, dotfiles, browser profile, cargo cache)
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
    options = [
      "noatime"
      "commit=60"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [
      "noatime"
      "umask=0077"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/PERSIST";
    fsType = "ext4";
    options = [
      "noatime"
      "commit=60"
      "nofail"
      "x-systemd.device-timeout=15s"
    ];
  };
}
