# persist-setup: find or create the PERSIST partition on the stick we booted from.
# Never exits non-zero: a failure must not stop the system from booting.
set -u

log() { echo "persist-setup: $*"; }

mount_home() {
  if mount -o noatime,commit=60 "$1" /home; then
    install -d -m 0700 -o "$USER_NAME" -g users "/home/$USER_NAME"
    log "mounted $1 on /home"
  else
    log "could not mount $1; /home stays in RAM"
  fi
}

# 1. Already created on an earlier boot?
udevadm settle || true
part="$(blkid -L PERSIST 2>/dev/null || true)"
if [ -n "$part" ]; then
  mount_home "$part"
  exit 0
fi

# 2. Find the stick we booted from (the device holding the ISO).
src="$(blkid -L "$LIVE_LABEL" 2>/dev/null || true)"
if [ -z "$src" ]; then
  log "not booted from the USB image; /home stays in RAM"
  exit 0
fi
parent="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1)"
if [ -n "$parent" ]; then disk="/dev/$parent"; else disk="$src"; fi

if [ "$(lsblk -dno TYPE "$disk" 2>/dev/null)" != "disk" ] || [ "$(blockdev --getro "$disk")" != "0" ]; then
  log "$disk is not a writable disk; /home stays in RAM"
  exit 0
fi

ptype="$(blkid -p -o value -s PTTYPE "$disk" 2>/dev/null || true)"
before="$(lsblk -rno PATH,TYPE "$disk" | awk '$2=="part"{print $1}' | sort -V)"

case "$ptype" in
  gpt)
    sgdisk -e "$disk" >/dev/null 2>&1 || true # move the backup GPT to the real end of the stick
    first="$(sgdisk -F "$disk" 2>/dev/null | tail -n1)"
    last="$(sgdisk -E "$disk" 2>/dev/null | tail -n1)"
    ss="$(blockdev --getss "$disk")"
    if ! [[ "$first" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]] || [ $(( (last - first + 1) * ss )) -lt 2147483648 ]; then
      log "less than 2 GiB free on $disk; /home stays in RAM"
      exit 0
    fi
    sgdisk -n 0:0:0 -t 0:8300 -c 0:PERSIST "$disk" >/dev/null 2>&1 || { log "sgdisk failed"; exit 0; }
    ;;
  dos)
    echo ',,83' | sfdisk --append --no-reread "$disk" >/dev/null 2>&1 || { log "no free space or free slot on $disk"; exit 0; }
    ;;
  *)
    log "unknown partition table '$ptype' on $disk; /home stays in RAM"
    exit 0
    ;;
esac

partx -a "$disk" >/dev/null 2>&1 || partx -u "$disk" >/dev/null 2>&1 || true
udevadm settle || true

# 3. Find the new partition (the one that was not there before).
newpart=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  after="$(lsblk -rno PATH,TYPE "$disk" | awk '$2=="part"{print $1}' | sort -V)"
  newpart="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | tail -n1)"
  [ -n "$newpart" ] && break
  sleep 1
done
if [ -z "$newpart" ]; then
  log "new partition did not appear; reboot once and it will be picked up"
  exit 0
fi

mkfs.ext4 -F -q -m 0 -L PERSIST "$newpart" || { log "mkfs failed"; exit 0; }
mount_home "$newpart"
exit 0
