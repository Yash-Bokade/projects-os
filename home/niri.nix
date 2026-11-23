# niri: scrollable-tiling Wayland compositor.
# Sharp corners, animated, primary colour as the active-window border.
{ theme, ... }:
{
  xdg.configFile."niri/config.kdl".text = ''
    prefer-no-csd

    hotkey-overlay {
        skip-at-startup
    }

    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png"

    environment {
        NIXOS_OZONE_WL "1"
    }

    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
            dwt
        }
        focus-follows-mouse max-scroll-amount="0%"
    }

    cursor {
        hide-after-inactive-ms 3000
    }

    layout {
        gaps 10
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        default-column-width { proportion 0.5; }

        // The primary colour is the border of the active window.
        focus-ring {
            off
        }
        border {
            on
            width 2
            active-color "${theme.primary}"
            inactive-color "${theme.border}"
            urgent-color "${theme.secondary}"
        }
    }

    animations {
        workspace-switch {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        horizontal-view-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-resize {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-open {
            duration-ms 180
            curve "ease-out-expo"
        }
        window-close {
            duration-ms 150
            curve "ease-out-quad"
        }
    }

    // Sharp corners everywhere.
    window-rule {
        geometry-corner-radius 0
        clip-to-geometry true
    }

    // Floating helper windows (nmtui, bluetui, device manager ...).
    window-rule {
        match app-id="dev.zei.float"
        open-floating true
        default-column-width { fixed 900; }
        default-window-height { fixed 560; }
    }
    window-rule {
        match app-id="pavucontrol"
        match app-id="nm-connection-editor"
        match app-id="blueman-manager"
        match app-id="org.gnome.DiskUtility"
        open-floating true
    }

    spawn-at-startup "desktop-start"
    spawn-at-startup "waybar"
    spawn-at-startup "swayidle" "-w" "timeout" "300" "eww open screensaver" "resume" "eww close screensaver" "timeout" "900" "niri msg action power-off-monitors" "resume" "niri msg action power-on-monitors"

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Apps
        Mod+Return { spawn "ghostty"; }
        Mod+D { spawn "rofi" "-show" "drun"; }
        Mod+Shift+D { spawn "devmgr"; }
        Mod+W { spawn "firefox"; }
        Mod+Z { spawn "zeditor"; }
        Mod+Shift+O { spawn "obs"; }
        Mod+E { spawn "ghostty" "--class=dev.zei.float" "-e" "yazi"; }
        Mod+N { spawn "ghostty" "--class=dev.zei.float" "-e" "nmtui"; }
        Mod+B { spawn "ghostty" "--class=dev.zei.float" "-e" "bluetui"; }
        Mod+Shift+Escape { spawn "powermenu"; }

        // Windows
        Mod+Q { close-window; }
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-window-down; }
        Mod+Up { focus-window-up; }
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }

        Mod+Ctrl+Left { move-column-left; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+Down { move-window-down; }
        Mod+Ctrl+Up { move-window-up; }
        Mod+Ctrl+H { move-column-left; }
        Mod+Ctrl+L { move-column-right; }
        Mod+Ctrl+J { move-window-down; }
        Mod+Ctrl+K { move-window-up; }

        Mod+Home { focus-column-first; }
        Mod+End { focus-column-last; }
        Mod+BracketLeft { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }

        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C { center-column; }
        Mod+V { toggle-window-floating; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Tab { toggle-overview; }

        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

        // Screenshots (saved to ~/Pictures/Screenshots)
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // Media keys
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }

        Mod+Shift+P { power-off-monitors; }
        Mod+Shift+E { quit; }
    }
  '';
}
