# powermenu: shutdown / reboot / logout from rofi.
set -euo pipefail

choice="$(printf 'shutdown\nreboot\nlog out\nscreen off\n' | rofi -dmenu -i -p "power")"

case "$choice" in
  shutdown)   sync; systemctl poweroff ;;
  reboot)     sync; systemctl reboot ;;
  "log out")  niri msg action quit --skip-confirmation ;;
  "screen off") niri msg action power-off-monitors ;;
  *) exit 0 ;;
esac
