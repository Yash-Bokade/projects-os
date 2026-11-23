{ pkgs, vars, ... }:
{
  users.users.${vars.user} = {
    isNormalUser = true;
    description = vars.fullName;
    shell = pkgs.bash;
    initialPassword = vars.initialPassword;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  # /home lives on the PERSIST partition, so these survive on the pendrive.
  systemd.tmpfiles.rules = [
    "d /home/${vars.user}/Projects 0755 ${vars.user} users -"
    "d /home/${vars.user}/Pictures 0755 ${vars.user} users -"
    "d /home/${vars.user}/Pictures/Screenshots 0755 ${vars.user} users -"
    "d /home/${vars.user}/Videos 0755 ${vars.user} users -"
  ];
}
