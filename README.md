# portable-nixos

A complete NixOS 26.05 system that lives on a **pendrive or SD card** and boots on almost any UEFI PC.
Flake + Home Manager, Wayland, **niri**, **ghostty**, **rofi**, **Zed**, **Rust**, **OBS**, a minimal Firefox,
and an Omarchy-style mono theme with sharp corners, animations and a massive-clock screensaver.

> Status: written without access to a Nix evaluator, so the first build may need a small fix
> (a renamed option, a typo). Run the **check** workflow first: it evaluates both systems in a few minutes
> and prints the exact file and line of any error.

## How the drive is laid out

| Partition | Label     | Size        | Mount   | What lives there |
|-----------|-----------|-------------|---------|------------------|
| 1         | `NIXBOOT` | 512 MiB     | `/boot` | GRUB, installed to the UEFI *fallback* path, so no host NVRAM is touched |
| 2         | `NIXROOT` | 28 GiB      | `/`     | The OS and the Nix store (everything installed once, shared by all projects) |
| 3         | `PERSIST` | rest (20 GiB+) | `/home` | Projects, dotfiles, Firefox profile, cargo cache, this repo |

Needs a drive of **at least 50 GiB** (a 64 GB stick leaves roughly 30 GiB for `/home`).
Partitions are mounted by *label*, so the stick works in any USB port or card reader.
Reinstalling the OS never touches `PERSIST` unless you rerun `install.sh` (which wipes the whole device).

Flash-friendly choices: `noatime`, 60 s commit interval, journald in RAM, `/tmp` in RAM, zram swap,
no Firefox disk cache, weekly garbage collection (generations older than 7 days), store hard-link optimisation.

## Prebuilt ISO (GitHub Actions + Releases)

There are two ways to get this OS on a stick:

| | Live ISO (this section) | `scripts/install.sh` (below) |
|---|---|---|
| Built by | GitHub Actions, downloaded from Releases | you, on a machine with Nix |
| `/home` (projects, settings) | persistent: auto-created partition | persistent: `PERSIST` partition |
| Packages you add later | live in RAM, gone on reboot | permanent (real `/nix` on the stick) |

### Publishing a release

1. Push this repo to GitHub (any name). Optionally run `nix flake lock` and commit `flake.lock` to pin versions.
2. (Recommended) Open **Actions -> check -> Run workflow**. It only *evaluates* the config (a few minutes) and
   reports typos or renamed options before you spend an hour building.
3. Publish: `git tag v0.1.0 && git push origin v0.1.0`, or **Actions -> build-iso -> Run workflow** and type a tag.
4. The `build-iso` workflow frees disk space on the runner, installs Nix, runs `nix build .#iso`
   (zstd-19 squashfs to keep it small), splits the ISO into **1900 MiB parts** (`portable-nixos-<tag>.iso.001`, `.002`, ...,
   under GitHub's 2 GiB limit), writes `SHA256SUMS` and join instructions, and creates the Release.

### Using the release

```sh
# 1. download every .00N part and SHA256SUMS into one folder, then join:
cat portable-nixos-v0.1.0.iso.0* > portable-nixos-v0.1.0.iso          # Linux / macOS
# Windows cmd:  copy /b a.iso.001+a.iso.002+a.iso.003 a.iso   (or 7-Zip: Combine files)

# 2. verify
sha256sum -c --ignore-missing SHA256SUMS

# 3. write it (replace /dev/sdX; balenaEtcher or Rufus in "DD Image" mode also work)
sudo dd if=portable-nixos-v0.1.0.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Use a stick **bigger than the image** (e.g. 64 GB). Do not use Ventoy; the image must be written directly.

### Persistence on the live ISO

`modules/system/persist-live.nix` runs a small service early in boot:

1. a partition labelled `PERSIST` exists -> mount it on `/home`;
2. otherwise, if the stick has 2 GiB+ of unused space, create a `PERSIST` partition there, format ext4, mount it;
3. otherwise (DVD, VM, read-only media) `/home` stays in RAM for that session.

So your projects (`~/Projects`), browser profile, cargo cache and dotfiles survive reboots. What does **not**
survive on the live ISO is anything installed with Nix after boot (the system store is a RAM overlay); put what you
need in `modules/system/packages.nix` and rebuild the ISO, or use `scripts/install.sh` for a fully writable system.
Project dev shells reuse the packages baked into the ISO where possible.

## Install to a stick yourself (`scripts/install.sh`)

1. Boot any NixOS installer ISO (or a Linux with Nix), connect to the internet.
2. Get this repo, edit `vars.nix` (user name, hostname, initial password) and `theme.nix` (colours) if you like.
3. Run (replace `/dev/sdX` with the **pendrive**, check with `lsblk`):

```sh
sudo ./scripts/install.sh /dev/sdX        # 28 GiB OS partition
sudo ./scripts/install.sh /dev/sdX 24     # or pick another OS size
```

The script shows the device, makes you type its path to confirm, partitions, formats, runs
`nixos-install --flake .#portable`, and copies the repo to `~/portable-nixos` on the stick.
Boot from the drive via your firmware's boot menu, log in (initial password from `vars.nix`), run `passwd`.

Change the system later: edit files in `~/portable-nixos`, then `rebuild` (alias for
`sudo nixos-rebuild switch --flake ~/portable-nixos#portable`).

## What is where

```
.github/workflows/
  build-iso.yml           build ISO -> split in 1900 MiB parts -> GitHub Release
  check.yml               evaluate-only sanity check (fast)
flake.nix                 inputs (nixpkgs 26.05, home-manager 26.05), systems "portable" + "live", `.#iso`
vars.nix                  user name, hostname, initial password
theme.nix                 EVERY colour and the font. Change here, everything follows.
hosts/common/home.nix     Home Manager glue shared by both systems
hosts/portable/           the installed system (install.sh)
hosts/live/               the live ISO (iso-image.nix, autologin, squashfs settings)
modules/system/
  kernel.nix              kernel, USB/SD initrd drivers, tmpfs, zram, volatile logs (shared)
  boot.nix                GRUB removable-EFI (installed system only)
  persist-live.nix        live ISO: create/mount persistent /home  (+ persist-setup.sh)
  storage.nix             the three labelled partitions
  hardware.nix            all firmware, microcode, graphics, udisks
  nix.nix                 flakes, GC, store optimisation
  network.nix             NetworkManager, Bluetooth, blueman, auto time zone
  audio.nix               PipeWire
  desktop.nix             niri, greetd login, portals (OBS capture), fonts
  users.nix               your user, ~/Projects etc.
  packages.nix            Rust toolchain, Nix tools, CLI + disk tools
  slim.nix                drops docs and default packages to save space
home/
  niri.nix                niri config (KDL), keybinds, animations, borders
  ghostty.nix             transparent terminal
  rofi.nix                launcher theme
  waybar.nix              minimal top bar
  eww.nix + eww.yuck      wallpaper widgets and the screensaver
  firefox.nix             minimal Firefox + uBlock Origin
  zed.nix                 Zed editor
  shell.nix               bash, starship prompt, git, direnv, yazi
  apps.nix                OBS, notifications (mako), auto-mount (udiskie)
  gtk.nix                 dark GTK theme and cursor
  scripts.nix + scripts/  mkproj, devmgr, powermenu, desktop-start, screensaver-preview
scripts/install.sh        partition + format + install onto the stick
```

## The look

* **Wallpaper**: solid dark gray (`swaybg`), with **eww** widgets on the background layer: big hour in the
  primary colour, minutes in the secondary colour, date, and a CPU / RAM / ROOT / HOME card.
* **Primary colour** (amber by default) is the border of the active window, the rofi border, bar highlights.
  **Secondary** (ember red) is for minutes, urgent state, errors. Edit both in `theme.nix`.
* **Sharp corners** everywhere (`geometry-corner-radius 0`, `border-radius: 0` in every stylesheet).
* **Animations**: niri springs for workspace / column movement, eased open / close.
* **Terminal**: ghostty at 85 % opacity (`theme.opacity`).
* **Screensaver**: after 5 minutes idle a full-screen overlay shows a 360 px time and the date;
  any key or mouse movement dismisses it. After 15 minutes the screen powers off.
  Preview it any time with `screensaver-preview`.

## Keys (Mod = Super)

| Keys | Action |
|------|--------|
| `Mod+Return` | ghostty |
| `Mod+D` | rofi launcher |
| `Mod+W` / `Mod+Z` / `Mod+Shift+O` | Firefox / Zed / OBS |
| `Mod+E` | yazi file manager (floating) |
| `Mod+N` | Wi-Fi settings (`nmtui`, floating) |
| `Mod+B` | Bluetooth settings (`bluetui`, floating) |
| `Mod+Shift+D` | **device manager** (mount, unmount, safely remove, PCI/USB info) |
| `Mod+Q` | close window |
| `Mod+H/J/K/L` or arrows | focus; add `Ctrl` to move |
| `Mod+R`, `Mod+F`, `Mod+Shift+F`, `Mod+V` | cycle width, maximise column, fullscreen, float |
| `Mod+1..5`, `Mod+Shift+1..5` | workspaces / move window to workspace |
| `Mod+Tab` | overview |
| `Print`, `Ctrl+Print`, `Alt+Print` | screenshot region / screen / window |
| `Mod+Shift+Escape` | power menu |
| `Mod+Shift+/` | full key list |

Waybar: click **wifi** → `nmtui` (right-click: full GUI editor), click **bt** → `bluetui` (right-click: blueman),
click **vol** → pavucontrol.

## `mkproj`: create a project

```sh
mkproj            # asks for the name
mkproj my-app     # name given
```

Like `npm init` it asks for **name, version, description, template, keywords, author, license, git remote**,
prints a summary and asks "Is this OK?". Then it creates `~/Projects/<name>` (on the pendrive) with:

* a template: `rust` (`cargo init`), `node` (`package.json`), `python` (`pyproject.toml`), `elixir` (`mix new`), or `generic`
* `flake.nix` with a dev shell, `flake.lock`, `.envrc` (`use flake`, so the shell loads on `cd`)
* `.gitignore`, `README.md`, `LICENSE` (MIT), `.project.json` (all your answers + creation date)
* a git repo with an initial commit

Every project is also appended to `~/Projects/.registry.tsv` (date, name, template, path). List them with `projects`.

Why projects stay small: their flakes use `nixpkgs.url = "nixpkgs"`, which resolves to the exact nixpkgs
this OS was built from, so dev shells reuse packages already in `/nix/store`. Nothing is downloaded twice.

> I read "mix project" as "a new project", so there is a generic command plus an `elixir` template
> (`mix new`). If you meant something else, edit `home/scripts/mkproj.sh`; it is plain bash.

## Customising

* Colours / font / terminal opacity: `theme.nix`
* Packages for the whole machine: `modules/system/packages.nix`; per-user apps: `home/apps.nix`
* Keybinds and animations: `home/niri.nix`
* Screensaver delay: the `swayidle` line in `home/niri.nix` (seconds)
* Widgets: `home/eww.yuck` (layout) and `home/eww.nix` (styling)

## Notes and limits

* **UEFI only.** Legacy BIOS boot would need an extra BIOS-boot partition and GRUB i386-pc.
* **NVIDIA**: works with nouveau out of the box; proprietary drivers do not suit a portable image.
* First run of Zed downloads its Nix/TOML extensions; uBlock Origin installs on Firefox's first online start.
* Time zone is detected from your location (`automatic-timezoned`); remove that line in `network.nix` to disable.
* Use the power menu or `poweroff` before unplugging, and `devmgr` → "unmount + power off" for *other* drives.
* Free space: `nix-collect-garbage -d` and `df -h /`.

## Troubleshooting

* Black screen after login: switch to a TTY (`Ctrl+Alt+F2`), run `journalctl -b -u greetd` and `niri validate`.
* Widgets missing: run `eww logs`; remember `desktop-start` runs once at login.
* Eval error mentioning an option: the Nix message names the file and line; check the option in the
  Home Manager / NixOS 26.05 manual and adjust.
