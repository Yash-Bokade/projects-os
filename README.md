# nomad — a portable NixOS on a 28 GB stick

A pocket computer: the whole OS lives on one pendrive / SD card, boots on
almost any x86-64 machine (BIOS **or** UEFI, nothing is installed on the
host), and gives you a full desktop plus an offline Elixir dev
environment. This repository is built by GitHub Actions into a bootable
ISO — flash it and go.

- **niri** (scrollable tiling Wayland) with a mono-gray theme and the single NixOS-blue accent `#5277C3`
- **Ghostty** terminal (transparent), **Waybar**, **fuzzel** launcher
- **OBS Studio**, PipeWire audio, screenshot tool
- Device manager stack: GNOME Disks, `usbview`, `lshw`, `lspci`, `lsusb`
- WiFi + Bluetooth from the tray applets (`nm-applet`, `blueman`) or `nmtui`
- **Firefox** — slimmed with policies (no telemetry/pocket/studies, blank new tab, HTTPS-only)
- **LocalSend** — drop files to/from phones and laptops on the same network
- **Elixir first**: `mix` system-wide, `direnv` + `nix-direnv`, and `mkproj` — an `npm init`-style project creator
- A **massive mono clock** as the lock screen / screensaver
- `persist-setup` — one command that turns the stick's remaining ~20+ GB into persistent storage

## Repository layout

```
├── flake.nix                  identity (EDIT ME block) + inputs + ISO output
├── shared.nix                 the OS: services, packages, network, user
├── iso.nix                    the live image: boot, persistence, rescue
├── home.nix                   per-user apps and dotfiles (home-manager)
├── files/                     niri / ghostty / waybar / fuzzel / swaylock configs
├── modules/mkproj.*           the `mkproj` command
├── scripts/persist-setup.sh   enables persistence on the stick
└── .github/workflows/build-iso.yml   builds the ISO on every push
```

## 1. Get an ISO

### Via GitHub Actions (no local Nix needed)

1. Create a GitHub repository and push this folder to it (`main` branch).
   ```bash
   git init -b main
   git add -A
   git commit -m "nomad — portable NixOS"
   git remote add origin git@github.com:YOU/portable-nixos.git
   git push -u origin main
   ```
2. Open the repo's **Actions** tab and watch **Build Portable NixOS ISO**
   (it starts automatically on push; ~30–45 min). No secrets needed — the
   build only pulls from `cache.nixos.org`.
3. Download the artifact **portable-nixos-iso** (contains the `.iso` and
   its `.sha256`).
4. Optional releases: push a tag and the ISO is attached to a GitHub Release,
   ```bash
   git tag v1.0 && git push origin v1.0
   ```
   If the release step fails: repo **Settings → Actions → General →
   Workflow permissions** must be "Read and write".

`flake.lock` is committed, so every build uses the exact same package
versions until you run `nix flake update` and push again.

### Locally (if you have Nix)

```bash
nix build .#iso        # -> result/iso/*.iso
```

## 2. Flash the stick

Wipes the stick completely — move anything valuable off it first.

- **balenaEtcher** (Linux/macOS/Windows): select the ISO, select the stick, flash.
- **Rufus** (Windows): choose the ISO and pick **DD mode** when asked
  (ISO mode will not boot).
- **dd** (Linux/macOS):
  ```bash
  sudo dd if=portable-nixos-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=direct sync
  ```
  (`/dev/sdX` is the whole stick, not a partition.)

Boot it from the machine's boot menu (`F12` / `ESC` / `F2` / `F8`,
depending on vendor). **Secure Boot must be off** — the GRUB on the ISO
is not signed. BIOS (legacy/CSM) and UEFI both work; nothing touches the
host machine's disk or firmware.

## 3. First boot

- Log in at the `tuigreet` prompt: user **`dev`**, password **`nomad`**.
  (The password resets to this on every boot — a travel OS thing; the
  stick itself is the thing to keep safe.)
- Connect WiFi: click the tray applet, `Mod+Shift+N`, or run `nmtui`.
- Press `Mod+Shift+/` anytime for the interactive hotkey overlay.

Common keys (Mod = Super/Windows key):

| Keys | Does |
|---|---|
| `Mod+T` | Ghostty terminal |
| `Mod+D` | fuzzel launcher |
| `Mod+B` | Firefox |
| `Mod+O` | OBS Studio |
| `Mod+Shift+S` | LocalSend |
| `Mod+Shift+N` / `Mod+Shift+B` | WiFi / Bluetooth settings |
| `Mod+Shift+D` | GNOME Disks (device manager) |
| `Mod+Alt+L` | Lock screen — the big clock screensaver |
| `Mod+Q` / `Mod+W` | close window / tabbed column |
| `Mod+HJKL` / arrows | focus columns & windows |
| `Mod+U` / `Mod+I` | scroll workspaces |
| `Mod+1..9` | jump to workspace |
| `Mod+R` / `Mod+F` | resize column / maximize |
| `Mod+V` | float a window |
| `Print` | screenshot (`Ctrl+Print` screen, `Alt+Print` window) |
| `Mod+Shift+E` | log out |

## 4. Persistence — the 20+ GB

The live system runs from RAM: **nothing survives a reboot until you run
this once.** In a terminal:

```bash
sudo persist-setup
```

It finds the stick by itself (it only ever touches the stick that holds
the ISO), shows the free space, and after you type `YES`:

1. creates one btrfs partition labeled `persist` in the **unpartitioned
   free space at the end of the stick** — the ISO is never modified,
2. copies your current home onto it (projects, dotfiles, browser profile),
3. seeds it with your WiFi passwords, Bluetooth pairings, machine-id and
   the uid map,
4. tells you to reboot.

After the reboot, `impermanence` binds `/home` and that state back into
every boot. Verify with `ls /persist` and `df -h /home`. From then on:
`mkproj` projects, browser logins, saved WiFi networks, LocalSend
identity — all survive. Before setup, a `PERSISTENCE.txt` note in the
home folder reminds you.

**Space on a 28 GB stick** (really ~26.7 GiB): the ISO occupies
~2.5–3 GB, leaving **~22+ GiB** for the persist partition — and btrfs
zstd compression stretches projects even further.

**What does NOT persist:** packages. The installed software is baked
into the ISO; `nix build`/`nix profile` output and anything outside the
persisted paths lives in RAM and resets on reboot. To change what is
installed, edit this repo and let Actions build a new ISO.

### Updating to a newer ISO

Re-flashing a new ISO erases the persist partition — **back up first**:

```bash
# from the old boot, push your projects somewhere safe, e.g. via LocalSend
# to your phone/another machine, or rsync to any USB disk:
rsync -a ~/Projects /run/media/dev/<usb-disk>/
```

Then flash the new ISO, boot, run `sudo persist-setup` again (it recreates
and re-seeds the persist partition). If you prefer to keep the partition:
flash the ISO, boot once, and `persist-setup` will detect the existing
`persist` label and leave it alone — but know that a fresh ISO may expect
a newer config than old persisted files, so the backup route is the safe
one.

## 5. `mkproj` — Elixir projects the npm way

```bash
mkproj            # interactive: name, version, description, author,
                  # email, license, keywords, elixir version, supervisor, git
mkproj my_app     # same, name pre-filled
```

It scaffolds with `mix new`, writes a `flake.nix` dev shell (elixir +
elixir-ls, pinned or system Elixir), a `.envrc`, a README with every
answer plus the creation date, runs `git init -b main` with a first
commit, logs the project to `~/Projects/.projects.log`, and locks the dev
shell with `nix flake lock`. Projects land in `~/Projects` (on the
persist partition); `cd my_app` auto-enters the dev shell via direnv.
The system's nixpkgs registry makes `nix develop` work offline.

## 6. Customize the OS

Everything is in the repo — edit, push, download the new ISO:

- **Identity** (`dev`/`nomad`, timezone, locale): the `EDIT ME` block in `flake.nix`.
- **System packages/services**: `shared.nix` (add e.g. `pkgs.vscode-fhs` to `environment.systemPackages`).
- **User apps/dotfiles**: `home.nix`.
- **Desktop look and keys**: `files/` — `niri.kdl` (bindings, gaps, colors), `ghostty.conf` (opacity), `waybar.json/css`, `fuzzel.ini`, `swaylock.conf` (the clock).
- **What persists**: the directory list in `iso.nix` (`environment.persistence`).

To try edits without a full ISO rebuild, clone your fork on the stick as
`~/nomad` and run `rebuild` — the live system switches immediately
(packages fetched this way still reset on reboot; they are in RAM).

## Troubleshooting

- **Stick does not appear in the boot menu** — try another USB port
  (prefer USB2 ports on old machines), re-flash with DD mode (Rufus) or
  Etcher, and make sure Secure Boot is off in the firmware setup.
- **WiFi does not show networks** — firmware is included for most chips;
  check `rfkill list`, or `sudo nmtui` in a terminal. Bluetooth pairs via
  `blueman-manager` (`Mod+Shift+B`).
- **`persist-setup` says "could not find the boot stick"** — pass the
  device: `lsblk` to see it, then `sudo persist-setup /dev/sdX`.
- **`persist-setup` refuses ("not the nomad stick")** — it only operates
  on the disk containing the ISO; that is the safety check working.
- **Forgot to set up persistence and lost work** — anything not under the
  persisted paths is RAM-only; set up persistence before real work.
- **The greeter says login failed** — user `dev`, password `nomad`,
  exactly; caps lock is the usual culprit.
- **A rebuild in Actions fails** — read the failing step's log; usually a
  renamed package in nixpkgs after `nix flake update` (the error names the
  option/package to adjust).

## Ideas that fit naturally (not included)

- Enable `services.tailscale.enable` in `shared.nix` for remote rescue.
- Add `pkgs.elixir-ls` system-wide if you want LSP outside project shells.
- Pin the ISO's nixpkgs to `nixos-25.11` instead of `nixos-unstable` for
  a slower but calmer update cadence.
