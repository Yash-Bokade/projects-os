#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating Arch keyring and installing build dependencies (Archiso + C/GTK4 toolchain)..."
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm archiso curl jq tar gzip git squashfs-tools gcc make pkgconf gtk4

WORK_DIR="/tmp/archiso-work"
PROFILE_DIR="/tmp/projects-os-profile"
OUT_DIR="/workspace/out"

rm -rf "$WORK_DIR" "$PROFILE_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

echo "==> Compiling native C11 GTK4 binaries (projects-wizard, projects-settings)..."
make -C /workspace/os/src clean all
ls -lh /workspace/os/src/projects-wizard /workspace/os/src/projects-settings

echo "==> Cloning upstream Archiso releng baseline for up-to-date bootloaders..."
cp -a /usr/share/archiso/configs/releng "$PROFILE_DIR"

echo "==> Applying Projects OS profile overlay (preserving upstream bootmodes via pure awk)..."
awk '/^bootmodes=\(/,/\)/' "$PROFILE_DIR/profiledef.sh" > /tmp/upstream_bootmodes.txt
cp -a /workspace/os/archiso/profiledef.sh "$PROFILE_DIR/profiledef.sh"
if [[ -s /tmp/upstream_bootmodes.txt ]]; then
  awk '
    /^bootmodes=\(/ {
      while ((getline line < "/tmp/upstream_bootmodes.txt") > 0) print line
      close("/tmp/upstream_bootmodes.txt")
      skip = 1
      next
    }
    skip && /\)/ { skip = 0; next }
    !skip { print }
  ' "$PROFILE_DIR/profiledef.sh" > "$PROFILE_DIR/profiledef.sh.new"
  mv "$PROFILE_DIR/profiledef.sh.new" "$PROFILE_DIR/profiledef.sh"
fi

cp -a /workspace/os/archiso/packages.x86_64 "$PROFILE_DIR/packages.x86_64"
cp -a /workspace/os/archiso/airootfs/. "$PROFILE_DIR/airootfs/"

echo "==> Installing compiled native ELF binaries into airootfs/usr/local/bin..."
install -Dm755 /workspace/os/src/projects-wizard "$PROFILE_DIR/airootfs/usr/local/bin/projects-wizard"
install -Dm755 /workspace/os/src/projects-settings "$PROFILE_DIR/airootfs/usr/local/bin/projects-settings"

echo "==> Updating bootloader menu labels and kernel options..."
find "$PROFILE_DIR/efiboot" "$PROFILE_DIR/syslinux" "$PROFILE_DIR/grub" -type f 2>/dev/null | while read -r cfg; do
  sed -i 's/Arch Linux install medium/Projects OS (Hyprland + Niri)/g' "$cfg" || true
  sed -i 's/Arch Linux/Projects OS/g' "$cfg" || true
done

if [[ -f "$PROFILE_DIR/efiboot/loader/entries/01-archiso-x86_64-linux.conf" ]]; then
  cp "$PROFILE_DIR/efiboot/loader/entries/01-archiso-x86_64-linux.conf" \
     "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
  sed -i 's/^title.*/title   Projects OS (Live RAM Only - No Persistence)/' \
     "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
  sed -i '/^options / s/$/ projects.nopersist=1/' \
     "$PROFILE_DIR/efiboot/loader/entries/02-projects-os-nopersist.conf"
fi

echo "==> Fetching latest LocalSend Linux x86_64 binary from GitHub Releases..."
LS_JSON=$(curl -fsSL "https://api.github.com/repos/localsend/localsend/releases/latest")
LS_URL=$(echo "$LS_JSON" | jq -r '.assets[] | select(.name | test("linux-x86-64\\.tar\\.gz$"; "i")) | .browser_download_url' | head -n 1)

if [[ -n "$LS_URL" && "$LS_URL" != "null" ]]; then
  echo "Downloading LocalSend from: $LS_URL"
  mkdir -p "$PROFILE_DIR/airootfs/opt/localsend"
  curl -fsSL "$LS_URL" -o /tmp/localsend.tar.gz
  tar -xzf /tmp/localsend.tar.gz -C "$PROFILE_DIR/airootfs/opt/localsend"
  rm -f /tmp/localsend.tar.gz
  find "$PROFILE_DIR/airootfs/opt/localsend" -maxdepth 2 -name "localsend_app" -exec chmod +x {} +
else
  echo "WARNING: Could not resolve LocalSend tarball URL; continuing without bundled LocalSend."
fi

echo "==> Pre-seeding LazyVim starter template in /etc/skel/.config/nvim..."
mkdir -p "$PROFILE_DIR/airootfs/etc/skel/.config"
rm -rf "$PROFILE_DIR/airootfs/etc/skel/.config/nvim"
git clone --depth=1 https://github.com/LazyVim/starter "$PROFILE_DIR/airootfs/etc/skel/.config/nvim"
rm -rf "$PROFILE_DIR/airootfs/etc/skel/.config/nvim/.git"
cp -a /workspace/os/archiso/airootfs/etc/skel/.config/nvim/. "$PROFILE_DIR/airootfs/etc/skel/.config/nvim/"

echo "==> Pre-seeding initial theme, hotkeys, Niri config, Waybar CSS, and SHORTCUTS.txt via pure Bash..."
HOME="$PROFILE_DIR/airootfs/etc/skel" bash "$PROFILE_DIR/airootfs/usr/local/bin/projects-apply-config" || true

echo "==> Removing conflicting releng services (tty1 autologin & systemd-networkd)..."
rm -rf "$PROFILE_DIR/airootfs/etc/systemd/system/getty@tty1.service.d"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -f "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service"

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
