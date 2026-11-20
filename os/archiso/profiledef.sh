#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="projects-os"
iso_label="PROJECTS_OS"
iso_publisher="Projects OS <https://github.com>"
iso_application="Projects OS Portable Arch Linux (Hyprland + Niri)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp'
           'uefi-ia32.systemd-boot.eltorito' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/sudoers.d/projects-os"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/projects-persist"]="0:0:755"
  ["/usr/local/bin/projects-firstboot-hook"]="0:0:755"
  ["/usr/local/bin/projects-wizard"]="0:0:755"
  ["/usr/local/bin/projects-settings"]="0:0:755"
  ["/usr/local/bin/projects-reset"]="0:0:755"
  ["/usr/local/bin/projects-toggle-sysmon"]="0:0:755"
  ["/usr/local/bin/projects-toggle-hide-all"]="0:0:755"
  ["/usr/local/bin/projects-shortcuts-menu"]="0:0:755"
  ["/usr/local/bin/projects-apply-config"]="0:0:755"
  ["/usr/local/bin/projects-waybar-storage"]="0:0:755"
  ["/usr/local/bin/localsend"]="0:0:755"
)
