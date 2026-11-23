{ pkgs, theme, ... }:
{
  home.packages = [ pkgs.rofi ]; # rofi has native Wayland support

  xdg.configFile."rofi/config.rasi".text = ''
    configuration {
        modi: "drun,run";
        font: "${theme.font} ${toString theme.fontSize}";
        show-icons: false;
        display-drun: ">";
        display-run: "$";
        drun-display-format: "{name}";
    }

    * {
        bg: ${theme.surface};
        bg-alt: ${theme.surfaceAlt};
        fg: ${theme.fg};
        dim: ${theme.dim};
        primary: ${theme.primary};
        secondary: ${theme.secondary};
        background-color: transparent;
        text-color: @fg;
    }

    window {
        location: center;
        width: 560px;
        background-color: @bg;
        border: 2px;
        border-color: @primary;
        border-radius: 0;
    }

    mainbox {
        padding: 12px;
        spacing: 10px;
        children: [ inputbar, listview ];
    }

    inputbar {
        spacing: 8px;
        padding: 8px;
        background-color: @bg-alt;
        children: [ prompt, entry ];
    }

    prompt { text-color: @primary; }

    entry {
        placeholder: "search";
        placeholder-color: @dim;
    }

    listview {
        lines: 8;
        columns: 1;
        fixed-height: true;
        scrollbar: false;
        spacing: 2px;
    }

    element {
        padding: 6px 8px;
        border-radius: 0;
    }

    element selected.normal {
        background-color: @primary;
        text-color: @bg;
    }

    element-text {
        background-color: transparent;
        text-color: inherit;
    }
  '';
}
