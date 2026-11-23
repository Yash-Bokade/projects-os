# Desktop widgets over the dark-gray wallpaper, plus the massive-clock screensaver.
# Layout lives in eww.yuck, colours are injected into the stylesheet from theme.nix.
{ pkgs, theme, ... }:
{
  home.packages = [ pkgs.eww ];

  xdg.configFile."eww/eww.yuck".source = ./eww.yuck;

  xdg.configFile."eww/eww.scss".text = ''
    * {
      all: unset;
      font-family: "${theme.font}";
      color: ${theme.fg};
    }

    /* ---- clock widget ---- */
    .clock-h {
      font-size: 150px;
      font-weight: 300;
      color: ${theme.primary};
    }
    .clock-m {
      font-size: 150px;
      font-weight: 300;
      margin-left: 70px;
      color: ${theme.secondary};
    }
    .clock-day {
      font-size: 22px;
      color: ${theme.primary};
    }
    .clock-date {
      font-size: 22px;
      color: ${theme.secondary};
    }

    /* ---- system card ---- */
    .card {
      padding: 22px 26px;
      min-width: 320px;
      background-color: rgba(20, 20, 20, 0.55);
      border-left: 2px solid ${theme.primary};
    }
    .card-title {
      font-size: 13px;
      font-weight: bold;
      color: ${theme.primary};
    }
    .card-sub {
      font-size: 12px;
      color: ${theme.dim};
    }
    .meter-label {
      font-size: 12px;
      font-weight: bold;
      color: ${theme.secondary};
    }
    .meter-value {
      font-size: 12px;
      color: ${theme.fg};
    }
    .meter-bar trough {
      min-height: 4px;
      background-color: ${theme.border};
    }
    .meter-bar highlight {
      background-color: ${theme.primary};
    }
    .meter-bar slider {
      min-width: 0px;
      min-height: 0px;
      opacity: 0;
    }

    /* ---- screensaver ---- */
    .ss {
      background-color: #0e0e0e;
    }
    .ss-h {
      font-size: 360px;
      font-weight: 300;
      color: ${theme.primary};
    }
    .ss-colon {
      font-size: 360px;
      font-weight: 300;
      color: ${theme.dim};
    }
    .ss-m {
      font-size: 360px;
      font-weight: 300;
      color: ${theme.secondary};
    }
    .ss-date {
      font-size: 44px;
      color: ${theme.fg};
    }
  '';
}
