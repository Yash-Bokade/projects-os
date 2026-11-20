# Projects OS (Zero-Python — Pure C + Shell Edition)

A minimalist, ultra-fast portable Arch Linux live OS built for a **32 GB USB flash drive (27.25 GB usable)** with **zero Python runtime**, **native compiled C (GTK4) ELF binaries**, **pure Bash + `jq` system tooling**, automatic **15 GB persistence**, dual Wayland compositors (**Hyprland + Niri**), **LazyVim**, and one-click **Project Reset**.

---

## Architecture Highlights (0% Python)

- **Native C11 GTK4 Binaries (`os/src/`)**:
  - `projects-wizard` — Compiled native x86_64 ELF binary for First-Boot Wi-Fi/Ethernet verification & project stack installation (`mise` + `pacman` + LazyVim extras).
  - `projects-settings` — Compiled native x86_64 ELF binary using GLib `GKeyFile` for live matte themes, Hyprland/Niri hotkeys, OBS/LocalSend export paths, and Project Reset.
- **Pure Shell + `jq` System Tooling (`os/archiso/airootfs/usr/local/bin/`)**:
  - `projects-persist` — Auto-creates and mounts a 15 GB `ext4` partition (`PROJECTS_PERSIST`) in trailing USB free space on first boot (Rufus DD mode).
  - `projects-apply-config` — Pure Bash config engine syncing `~/.config/projects-os/settings.conf` to Hyprland, Niri, Waybar, Foot, Fuzzel, OBS Studio, LocalSend, and `~/SHORTCUTS.txt`.
  - `projects-reset` — Project Reset Only: wipes `~/Projects`, installed language toolchains, LazyVim extras, and Firefox session caches while preserving Wi-Fi profiles, SSH keys, Git config, and OS settings.
  - `projects-toggle-sysmon`, `projects-toggle-hide-all`, `projects-shortcuts-menu`, `projects-waybar-storage`, `projects-firstboot-hook`.
- **Up-to-Date Node 24 GitHub Actions**:
  - `actions/checkout@v7`, `softprops/action-gh-release@v3`, `actions/configure-pages@v6`, `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`.

---

## Repository Structure

```text
projects-os/
├── .github/workflows/
│   ├── build-iso.yml          # Compiles C binaries + builds Archiso + publishes Release ISO
│   └── deploy-website.yml     # Automated GitHub Pages deployment
├── os/
│   ├── build.sh               # Pure Bash CI build script (compiles os/src -> ELF, runs mkarchiso)
│   ├── src/
│   │   ├── Makefile           # Compiles stripped GTK4 C11 binaries
│   │   ├── projects-wizard.c  # Native GTK4 First-Boot Connectivity & Stack Wizard
│   │   └── projects-settings.c# Native GTK4 Settings GUI (Themes, Hotkeys, Export Paths, Reset)
│   └── archiso/
│       ├── profiledef.sh      # Archiso profile & permissions
│       ├── packages.x86_64    # Official Arch packages (native GTK4 & shell tools only)
│       └── airootfs/          # Pure shell tools, greetd, systemd units, skel dotfiles
└── website/                   # Minimalist landing page & interactive preview
    ├── index.html
    ├── styles.css
    └── app.js
```

---

## Quick Start (From Windows — No Linux Machine Needed)

1. Push this folder to your GitHub repository's `main` branch:
   ```powershell
   git init
   git add .
   git commit -m "Projects OS (Zero-Python C + Shell)"
   git branch -M main
   git remote add origin https://github.com/<your-username>/projects-os.git
   git push -u origin main
   ```
2. Enable permissions in your GitHub repo:
   - **Settings → Actions → General → Workflow permissions** → **Read and write permissions**.
   - **Settings → Pages → Build and deployment → Source** → **GitHub Actions**.
3. Wait for `Build & Release Projects OS ISO` (~8–12 min), then download `projects-os-x86_64.iso` from **Releases**.
4. Flash onto your **32 GB SanDisk USB** using **Rufus** in **DD Image mode**.
5. Boot with Secure Boot disabled. Login: `dev` / password `projects`. Press **F2** at login to switch between **Hyprland** and **Niri**.
