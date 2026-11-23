{ theme, ... }:
let
  float = "ghostty --class=dev.zei.float -e";
in
{
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 28;
      spacing = 14;

      modules-left = [ "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [
        "network"
        "bluetooth"
        "pulseaudio"
        "battery"
      ];

      "niri/workspaces".format = "{index}";

      clock = {
        format = "{:%H:%M}";
        tooltip-format = "{:%A, %d %B %Y}";
      };

      network = {
        format-wifi = "wifi {signalStrength}%";
        format-ethernet = "eth";
        format-disconnected = "offline";
        tooltip-format = "{essid} {ipaddr}";
        on-click = "${float} nmtui";
        on-click-right = "nm-connection-editor";
      };

      bluetooth = {
        format = "bt off";
        format-on = "bt";
        format-connected = "bt {num_connections}";
        on-click = "${float} bluetui";
        on-click-right = "blueman-manager";
      };

      pulseaudio = {
        format = "vol {volume}%";
        format-muted = "muted";
        on-click = "pavucontrol";
      };

      battery = {
        format = "bat {capacity}%";
        format-charging = "chg {capacity}%";
        states = {
          warning = 25;
          critical = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "${theme.font}";
        font-size: 12px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: ${theme.surface};
        color: ${theme.fg};
        border-bottom: 2px solid ${theme.border};
      }

      #workspaces button {
        padding: 0 10px;
        color: ${theme.dim};
        background: transparent;
      }

      #workspaces button.active {
        color: ${theme.primary};
        border-bottom: 2px solid ${theme.primary};
      }

      #clock {
        color: ${theme.primary};
        font-weight: bold;
      }

      #network, #bluetooth, #pulseaudio, #battery {
        padding: 0 6px;
        color: ${theme.fg};
      }

      #battery.warning { color: ${theme.primary}; }
      #battery.critical { color: ${theme.secondary}; }
      #network.disconnected { color: ${theme.dim}; }
    '';
  };
}
