#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating Arch keyring and installing archiso build dependencies..."
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm archiso curl jq tar gzip git squashfs-tools

WORK_DIR="/tmp/archiso-work"
PROFILE_DIR="/tmp/projects-os-profile"
OUT_DIR="/workspace/out"

rm -rf "$WORK_DIR" "$PROFILE_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

echo "==> Cloning upstream Archiso releng baseline for up-to-date bootloaders..."
cp -a /usr/share/archiso/configs/releng "$PROFILE_DIR"

echo "==> Applying Projects OS profile overlay..."
# Preserve upstream releng bootmodes dynamically so future archiso updates never break CI
UPSTREAM_BOOTMODES=$(awk '/^bootmodes=\(/,/\)/' "$PROFILE_DIR/profiledef.sh")
cp -a /workspace/os/archiso/profiledef.sh "$PROFILE_DIR/profiledef.sh"
if [[ -n "$UPSTREAM_BOOTMODES" ]]; then
  python3 -c '
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
bm = sys.argv[2]
txt = p.read_text()
txt = re.sub(r"bootmodes=\([^)]*\)", bm, txt, count=1, flags=re.S)
p.write_text(txt)
' "$PROFILE_DIR/profiledef.sh" "$UPSTREAM_BOOTMODES"
fi
cp -a /workspace/os/archiso/packages.x86_64 "$PROFILE_DIR/packages.x86_64"
cp -a /workspace/os/archiso/airootfs/. "$PROFILE_DIR/airootfs/"

echo "==> Updating bootloader menu labels and kernel options..."
find "$PROFILE_DIR/efiboot" "$PROFILE_DIR/syslinux" "$PROFILE_DIR/grub" -type f 2>/dev/null | while read -r cfg; do
  sed -i 's/Arch Linux install medium/Projects OS (Hyprland + Niri)/g' "$cfg" || true
  sed -i 's/Arch Linux/Projects OS/g' "$cfg" || true
done

# Add a dedicated Live-RAM-Only fallback entry for systemd-boot
if [[ -f "$PROFILE_DIR/efiboot/loader/entries/01-archiso-x86_64-linux.conf" ]]; then
  cp "$PROFILE_DIR/efiboot/loader/entries/01-archiso-x86_64-linux.conf"      "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
  sed -i 's/^title.*/title   Projects OS (Live RAM Only - No Persistence)/'      "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
  sed -i '/^options / s/$/ projects.nopersist=1/'      "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
fi

echo "==> Fetching latest LocalSend Linux x86_64 binary from GitHub Releases..."
LS_JSON=$(curl -fsSL "https://api.github.com/repos/localsend/localsend/releases/latest")
LS_URL=$(echo "$LS_JSON" | jq -r '.assets[] | select(.name | test("linux-x86-64\.tar\.gz$"; "i")) | .browser_download_url' | head -n 1)

if [[ -n "$LS_URL" && "$LS_URL" != "null" ]]; then
  echo "Downloading LocalSend from: $LS_URL"
  mkdir -p "$PROFILE_DIR/airootfs/opt/localsend"
  curl -fsSL "$LS_URL" -o /tmp/localsend.tar.gz
  tar -xzf /tmp/localsend.tar.gz -C "$PROFILE_DIR/airootfs/opt/localsend"
  rm -f /tmp/localsend.tar.gz
  # Ensure executable permissions
  find "$PROFILE_DIR/airootfs/opt/localsend" -maxdepth 2 -name "localsend_app" -exec chmod +x {} +
else
  echo "WARNING: Could not resolve LocalSend tarball URL; continuing without bundled LocalSend."
fi

echo "==> Pre-seeding LazyVim starter template in /etc/skel/.config/nvim..."
mkdir -p "$PROFILE_DIR/airootfs/etc/skel/.config"
rm -rf "$PROFILE_DIR/airootfs/etc/skel/.config/nvim"
git clone --depth=1 https://github.com/LazyVim/starter "$PROFILE_DIR/airootfs/etc/skel/.config/nvim"
rm -rf "$PROFILE_DIR/airootfs/etc/skel/.config/nvim/.git"
# Copy our Projects OS LazyVim overrides
cp -a /workspace/os/archiso/airootfs/etc/skel/.config/nvim/. "$PROFILE_DIR/airootfs/etc/skel/.config/nvim/"



echo "==> Pre-seeding initial theme, hotkeys, Niri config, Waybar CSS, and SHORTCUTS.txt into /etc/skel..."
HOME="$PROFILE_DIR/airootfs/etc/skel" python3 "$PROFILE_DIR/airootfs/usr/local/bin/projects-apply-config" || true

echo "==> Enabling Projects OS systemd services..."
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "$PROFILE_DIR/airootfs/etc/systemd/system/local-fs.target.wants"
ln -sf /etc/systemd/system/projects-persist.service "$PROFILE_DIR/airootfs/etc/systemd/system/local-fs.target.wants/projects-persist.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/bluetooth.service "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/greetd.service "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/greetd.service"
ln -sf /usr/lib/systemd/system/power-profiles-daemon.service "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/power-profiles-daemon.service"
ln -sf /usr/lib/systemd/system/acpid.service "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/acpid.service"
ln -sf /usr/lib/systemd/system/graphical.target "$PROFILE_DIR/airootfs/etc/systemd/system/default.target"

echo "==> Running mkarchiso..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

echo "==> Build complete! Output:"
ls -lh "$OUT_DIR"
