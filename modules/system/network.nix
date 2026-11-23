{ pkgs, vars, ... }:
{
  networking = {
    hostName = vars.hostname;
    networkmanager.enable = true; # Wi-Fi + Ethernet; `nmtui` is the TUI front-end
    useDHCP = false;
    firewall.enable = true;
  };

  services.resolved.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true; # GUI fallback: blueman-manager

  # Picks the time zone from your location, so the clock is right in every country.
  services.automatic-timezoned.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = [
    pkgs.networkmanagerapplet # nm-connection-editor (GUI)
    pkgs.bluetui # Bluetooth TUI
  ];
}
