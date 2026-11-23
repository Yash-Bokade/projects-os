# Persistent /home for the live ISO.
#
# When the ISO is written to a stick with `dd` / Etcher / Rufus (DD mode), everything after the
# image is unused space. On boot this service:
#   1. looks for a partition labelled PERSIST and mounts it on /home, or
#   2. if there is none, creates one in the free space (>= 2 GiB) of the boot stick,
#      formats it ext4 and mounts it.
# If anything is not possible (booted from a DVD / VM, read-only medium, no free space) it does
# nothing and /home stays in RAM for that session.
{ pkgs, vars, ... }:
{
  systemd.services.persist-setup = {
    description = "Create and mount persistent /home on the USB stick";
    wantedBy = [ "local-fs.target" ];
    before = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
    ];
    after = [
      "systemd-udevd.service"
      "systemd-udev-trigger.service"
    ];
    unitConfig.DefaultDependencies = false;

    path = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.gptfdisk
      pkgs.e2fsprogs
      pkgs.gawk
      pkgs.gnugrep
      pkgs.systemd
    ];
    environment = {
      LIVE_LABEL = vars.isoLabel;
      USER_NAME = vars.user;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash ${./persist-setup.sh}";
    };
  };
}
