# devmgr: rofi "device manager" for removable drives and hardware info.
set -euo pipefail

menu() { rofi -dmenu -i -p "$1"; }

hw_label="[ hardware info: PCI + USB ]"

list_devices() {
  lsblk -J -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,TYPE | jq -r '
    .. | objects
    | select(.type == "part" and .fstype != null)
    | select((.mountpoint // "") as $m | (["/", "/boot", "/home", "/nix/store"] | index($m)) == null)
    | "/dev/\(.name)\t\(.size)\t\(.fstype)\t\(.label // "-")\t\(if .mountpoint then "mounted: " + .mountpoint else "not mounted" end)"'
}

choice="$( { list_devices; printf '%s\n' "$hw_label"; } | menu "devices")"
[ -n "$choice" ] || exit 0

if [ "$choice" = "$hw_label" ]; then
  exec ghostty --class=dev.zei.float -e bash -c 'lspci -k; echo; lsusb; echo; read -r -p "press enter to close " _'
fi

dev="${choice%%$'\t'*}"
if [[ "$choice" == *"not mounted"* ]]; then
  actions="mount"
else
  actions=$'unmount\nunmount + power off'
fi

action="$(printf '%s\n' "$actions" | menu "$dev")"
[ -n "$action" ] || exit 0

case "$action" in
  mount)
    out="$(udisksctl mount -b "$dev" 2>&1)" && notify-send "devmgr" "$out" || notify-send "devmgr: mount failed" "$out"
    ;;
  unmount)
    out="$(udisksctl unmount -b "$dev" 2>&1)" && notify-send "devmgr" "$out" || notify-send "devmgr: unmount failed" "$out"
    ;;
  "unmount + power off")
    parent="/dev/$(lsblk -no PKNAME "$dev" | head -n1)"
    udisksctl unmount -b "$dev" >/dev/null 2>&1 || true
    out="$(udisksctl power-off -b "$parent" 2>&1)" && notify-send "devmgr" "Safe to remove $parent" || notify-send "devmgr: power-off failed" "$out"
    ;;
esac
