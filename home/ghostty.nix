{ theme, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = theme.font;
      font-size = theme.fontSize;

      # Transparent terminal, no decorations, sharp edges.
      background-opacity = theme.opacity;
      window-decoration = false;
      window-padding-x = 10;
      window-padding-y = 8;
      confirm-close-surface = false;
      cursor-style = "block";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;

      background = theme.surface;
      foreground = theme.fg;
      cursor-color = theme.primary;
      selection-background = theme.primary;
      selection-foreground = theme.surface;

      palette = [
        "0=${theme.surface}"
        "1=${theme.secondary}"
        "2=#8a8a8a"
        "3=${theme.primary}"
        "4=#9a9a9a"
        "5=#aaaaaa"
        "6=#bababa"
        "7=${theme.fg}"
        "8=${theme.border}"
        "9=${theme.secondary}"
        "10=#a0a0a0"
        "11=${theme.primary}"
        "12=#b0b0b0"
        "13=#c0c0c0"
        "14=#d0d0d0"
        "15=#ffffff"
      ];
    };
  };
}
