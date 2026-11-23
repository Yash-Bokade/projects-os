#!/usr/bin/env bash
# Install the portable NixOS onto a pendrive / SD card.
# Run as root from any NixOS installer ISO (or any Linux with Nix installed).
#
#   sudo ./scripts/install.sh /dev/sdX [ROOT_SIZE_GIB]
#
# Layout: 512M EFI | ROOT_SIZE_GIB (default 28) OS | rest = PERSIST (/home).
# EVERYTHING ON THE TARGET DEVICE IS ERASED.
set -euo pipefail

die() { printf 'install: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
DEV="${1:-}"
ROOT_GIB="${2:-28}"
[ -b "$DEV" ] || die "usage: sudo $0 /dev/sdX [root_size_gib]"
[[ "$ROOT_GIB" =~ ^[0-9]+$ ]] || die "root size must be a whole number of GiB"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NIX_CONFIG="experimental-features = nix-command flakes"
USER_NAME="$(nix eval --raw --impure --expr "(import $REPO/vars.nix).user")"

if lsblk -nro MOUNTPOINT "$DEV" | grep -qx '/'; then
  die "$DEV holds the running system's root filesystem"
fi

SIZE_GIB=$(( $(blockdev --getsize64 "$DEV") / 1024 / 1024 / 1024 ))
echo
lsblk -o NAME,SIZE,MODEL,TRAN,RM "$DEV"
echo
echo "Target: $DEV (${SIZE_GIB} GiB). Root partition: ${ROOT_GIB} GiB."
if [ "$SIZE_GIB" -lt $(( ROOT_GIB + 21 )) ]; then
  die "device too small: need at least $(( ROOT_GIB + 21 )) GiB for ${ROOT_GIB} GiB OS + ~20 GiB persistent storage"
fi
if [ "$(lsblk -dno RM "$DEV")" != "1" ]; then
  echo "WARNING: $DEV does not report itself as removable. Is this an internal disk?"
fi
read -r -p "This ERASES $DEV. Type the device path to continue: " confirm
[ "$confirm" = "$DEV" ] || die "aborted"

part() {
  case "$DEV" in
    *[0-9]) printf '%sp%s' "$DEV" "$1" ;;
    *) printf '%s%s' "$DEV" "$1" ;;
  esac
}

if [ ! -f "$REPO/flake.lock" ]; then
  echo "==> locking flake inputs"
  (cd "$REPO" && nix flake lock)
fi

echo "==> partitioning"
umount -R /mnt 2>/dev/null || true
wipefs -a "$DEV"
ROOT_END=$(( 513 + ROOT_GIB * 1024 ))
parted -s "$DEV" mklabel gpt
parted -s "$DEV" mkpart NIXBOOT fat32 1MiB 513MiB
parted -s "$DEV" set 1 esp on
parted -s "$DEV" mkpart NIXROOT ext4 513MiB "${ROOT_END}MiB"
parted -s "$DEV" mkpart PERSIST ext4 "${ROOT_END}MiB" 100%
partprobe "$DEV" || true
udevadm settle
sleep 2

echo "==> formatting"
mkfs.fat -F32 -n NIXBOOT "$(part 1)"
mkfs.ext4 -F -q -m 1 -L NIXROOT "$(part 2)"
mkfs.ext4 -F -q -m 0 -L PERSIST "$(part 3)"
udevadm settle

echo "==> mounting"
mount "$(part 2)" /mnt
mkdir -p /mnt/boot /mnt/home
mount "$(part 1)" /mnt/boot
mount "$(part 3)" /mnt/home

echo "==> installing NixOS (this downloads a few GB)"
nixos-install --root /mnt --flake "$REPO#portable" --no-root-passwd

echo "==> copying the config repo into the persistent home"
mkdir -p "/mnt/home/$USER_NAME"
cp -a "$REPO" "/mnt/home/$USER_NAME/portable-nixos"
nixos-enter --root /mnt -c "chown -R $USER_NAME:users /home/$USER_NAME"

sync
umount -R /mnt
echo
echo "Done. Boot from the drive (pick it in your firmware's boot menu)."
echo "Log in as '$USER_NAME' and change the initial password with: passwd"
