#!/usr/bin/env bash
# ==========================================================================
#  persist-setup — give the nomad live system a persistent home
#
#  The ISO boots read-only into RAM: nothing survives a reboot until you
#  run this once. It takes the UNPARTITIONED free space at the end of the
#  boot stick (on a 28 GB stick that is ~20+ GB), creates a btrfs
#  partition labeled "persist", copies your current home and state onto
#  it — and after the next reboot impermanence binds it all back at
#  every boot.
#
#      sudo persist-setup              # auto-detects the boot stick
#      sudo persist-setup /dev/sdX     # or point at the stick yourself
#
#  Safety: it only ever APPENDS a partition to free space on the disk
#  that contains this very ISO (label NIXOS_NOMAD). It never touches the
#  ISO partition itself, other disks, or existing partitions.
# ==========================================================================
set -euo pipefail

ACCENT=$'\033[38;2;82;119;195m' # NixOS blue
DIM=$'\033[90m'
FG=$'\033[0m'
RED=$'\033[91m'

hi()  { printf '%s%s%s\n' "$ACCENT" "$*" "$FG"; }
say() { printf '%s\n' "$*"; }
dim() { printf '%s\n' "$DIM$*$FG"; }
die() { printf '%s%s%s\n' "$RED" "persist-setup: $*" "$FG" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run me as root:  sudo persist-setup"

command -v sgdisk >/dev/null || die "sgdisk missing (should ship with this OS)"
command -v mkfs.btrfs >/dev/null || die "btrfs-progs missing (should ship with this OS)"
command -v rsync >/dev/null || die "rsync missing (should ship with this OS)"

MNT="$(mktemp -d /tmp/persist-setup.XXXXXX)"
cleanup() { mountpoint -q "$MNT" && umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

ISO_LABEL="NIXOS_NOMAD" # isoImage.volumeID in iso.nix — keep in sync

# ---------- find the stick ------------------------------------------------------
DEV="${1-}"

if [[ -z "$DEV" ]]; then
        mapfile -t found < <(lsblk -rno PKNAME,FSTYPE | awk '$2 == "iso9660" && $1 != "" {print $1}' | sort -u)
        if [[ ${#found[@]} -eq 1 ]]; then
                DEV="/dev/${found[0]}"
        elif [[ ${#found[@]} -gt 1 ]]; then
                die "several disks contain an ISO (found: ${found[*]}). Pass one explicitly:  sudo persist-setup /dev/sdX"
        fi
fi

[[ -n "$DEV" && -b "$DEV" ]] || {
        dim "could not find the boot stick. Here are your disks:"
        say ""
        lsblk -o NAME,SIZE,RM,TYPE,FSTYPE,LABEL,MOUNTPOINTS 2>/dev/null || true
        say ""
        say "run me again with the stick as argument, e.g.:  sudo persist-setup /dev/sdX"
        exit 2
}

# ---------- safety checks -------------------------------------------------------
[[ "$DEV" =~ ^/dev/(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+)$ ]] ||
        die "refusing to operate on $DEV — pass a whole disk (like /dev/sdb), not a partition"

lsblk -rno LABEL "$DEV" | grep -qx "$ISO_LABEL" ||
        die "$DEV has no $ISO_LABEL filesystem on it — that is not the nomad stick. Refusing to touch it."

if lsblk -rno LABEL "$DEV" | grep -qx "persist"; then
        hi "a persist partition already exists on $DEV — nothing to do."
        mount -a 2>/dev/null || true
        mountpoint -q /persist && dim "mounted: $(findmnt -nro SIZE /persist 2>/dev/null || echo '?') at /persist"
        exit 0
fi

# partition device naming: nvme/mmcblk need a 'p' before the number
case "$DEV" in
*nvme* | *mmcblk*) PFX="${DEV}p" ;;
*) PFX="$DEV" ;;
esac

LOGSEC="$(lsblk -rno LOG-SEC "$DEV")"
TOTAL="$(sgdisk -p "$DEV" | awk '/^Disk /{print $3}')"
LAST_END="$(sgdisk -p "$DEV" | awk '$1 ~ /^[0-9]+$/ {if ($3 > m) m = $3} END {print m+0}')"
[[ "$TOTAL" =~ ^[0-9]+$ && "$LOGSEC" =~ ^[0-9]+$ ]] ||
        die "could not read the partition table of $DEV — is it healthy?"
FREE_SECTORS=$((TOTAL - LAST_END - 2048)) # keep room for the GPT backup
FREE_BYTES=$((FREE_SECTORS * LOGSEC))
FREE_GIB=$((FREE_BYTES / 1024 / 1024 / 1024))

hi "──────────────────────────────────────────────"
say " target stick : $DEV"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL "$DEV" 2>/dev/null || true
say ""
say " free space   : ${FREE_GIB} GiB (becomes the persist partition)"
if ((FREE_GIB < 8)); then
        die "only ${FREE_GIB} GiB free on $DEV — re-flash the ISO to a bigger stick (need >= 8 GiB free)."
fi
say ""
say " this APPENDS one partition to the free space on $DEV."
say " it does not modify the ISO or any other partition."
hi "──────────────────────────────────────────────"
say ""
read -r -p "$(printf '%stype YES to continue: %s' "$DIM" "$FG")" confirm
[[ "$confirm" == "YES" ]] || die "aborted — nothing was changed."

# ---------- partition + format --------------------------------------------------
hi ">> creating the partition"
# -n 0:0:0 = next free slot, rest of the disk; type defaults to "Linux
# filesystem" — the partition is found by its btrfs label, not its name
sgdisk -n 0:0:0 "$DEV" >/dev/null
partprobe "$DEV" 2>/dev/null || true
udevadm settle --timeout=15 2>/dev/null || true

NUM="$(sgdisk -p "$DEV" | awk '$1 ~ /^[0-9]+$/ {n = $1} END {print n}')"
PART="${PFX}${NUM}"
[[ -b "$PART" ]] || die "partition $PART did not appear (kernel still syncing?)"

hi ">> formatting ${PART} as btrfs (label: persist)"
mkfs.btrfs -f -L persist "$PART" >/dev/null

hi ">> copying your current home and state onto it"
mount -o compress=zstd,noatime "$PART" "$MNT"
mkdir -p "$MNT/home"
rsync -aHAX /home/ "$MNT/home/"

# seed the state directories impermanence will bind at boot
for d in \
        "etc/NetworkManager/system-connections" \
        "var/lib/NetworkManager" \
        "var/lib/bluetooth" \
        "var/lib/nixos"; do
        if [[ -d "/$d" ]]; then
                mkdir -p "$MNT/$d"
                rsync -a "/$d/" "$MNT/$d/"
        fi
done
if [[ -s /etc/machine-id ]]; then
        mkdir -p "$MNT/etc"
        cp /etc/machine-id "$MNT/etc/machine-id"
fi

# the reminder note has done its job
if [[ -n "${SUDO_USER:-}" ]]; then
        rm -f "$MNT/home/$SUDO_USER/PERSISTENCE.txt" "/home/$SUDO_USER/PERSISTENCE.txt"
fi

sync
umount "$MNT"

hi "──────────────────────────────────────────────"
say " done. the persist partition is ready (~${FREE_GIB} GiB)."
say ""
say " next: reboot (type: sudo reboot) — after that every boot binds"
say " /home, wifi passwords, bluetooth pairings and the machine id"
say " from the persist partition automatically."
say ""
say " verify after the reboot:   ls /persist   and   df -h /home"
hi "──────────────────────────────────────────────"
