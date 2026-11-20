# Projects OS

A minimalist, high-performance portable Arch Linux live OS built for a **32 GB USB flash drive (27.25 GB usable)** with automatic **15 GB persistence**, dual Wayland compositors (**Hyprland + Niri**), a **First-Boot Project Stack Wizard**, **GTK4 Settings GUI**, and one-click **Project Reset**.

---

## Key Features

- **Dual Compositors with Session Switcher**: Boot into either **Hyprland** or **Niri** via `greetd` + `tuigreet`.
- **Zero-Config 15 GB Persistence (Rufus Compatible)**: Flash the `.iso` in Rufus (**DD Image mode**). On first boot, Projects OS detects free space on the USB drive, creates and formats a `15 GB ext4` partition labeled `PROJECTS_PERSIST`, and mounts `/home/dev`, Wi-Fi credentials, and OS state persistently.
- **Hardware Ready**: Pre-loaded with `linux-firmware`, `sof-firmware` (Samsung Galaxy Book 4 speakers/mic), Intel VA-API/Vulkan, AMD/Nouveau fallback graphics, Intel/Realtek Wi-Fi & Ethernet, Bluetooth, and Wayland portals.
- **Minimalist Performance UI**: Solid matte theme (no wallpaper bloat), clean **Waybar** displaying CPU, RAM, Available Persistence Storage, Battery, and Network.
- **Hidden System Monitor (`Super + S`)**: `btop` stays completely hidden until toggled with `Super + S`.
- **Hide / Restore All Windows (`Super + D`)**: Works seamlessly in both Hyprland and Niri.
- **Searchable Shortcuts (`Super + /`) & `~/SHORTCUTS.txt`**: Fuzzy-searchable shortcut overlay synced automatically with the Settings GUI.
- **First-Boot Connectivity + Stack Wizard**: Connects to Wi-Fi/Ethernet and installs the latest **Java, Rust, Go, C/C++, Node.js, Python, Zig, Bun** via `mise`, automatically configuring **LazyVim** extras & LSPs.
- **Project Reset Only**: After pushing a finished project to GitHub, click **Project Reset** to wipe `~/Projects`, language toolchains, and browser session caches while **keeping Wi-Fi profiles, SSH keys, Git config, and OS settings intact**.
- **Curated Minimal Apps**: Minimal-UI Firefox, Neovim (LazyVim), Git, OpenSSH, LocalSend, OBS Studio, Foot terminal, Fuzzel launcher.

---

## Repository Structure

```text
projects-os/
├── .github/workflows/
│   ├── build-iso.yml          # Automated Archiso build + GitHub Release publisher
│   └── deploy-website.yml     # Automated GitHub Pages deployment
├── os/
│   ├── build.sh               # Archiso overlay builder script (used by CI)
│   └── archiso/
│       ├── profiledef.sh      # Archiso metadata & executable permissions
│       ├── packages.x86_64    # Official Arch packages + drivers
│       └── airootfs/          # Complete OS filesystem overlay
│           ├── etc/           # greetd, systemd services, skel dotfiles
│           └── usr/local/bin/ # Persistence, Wizard, Settings GUI, Reset, Shortcuts
└── website/                   # Minimalist landing page & interactive preview
    ├── index.html
    ├── styles.css
    └── app.js
```

---

## Quick Start (No Linux Machine Required)

1. **Create a new GitHub repository** (e.g., `your-username/projects-os`) and push this folder to the `main` branch:
   ```bash
   git init
   git add .
   git commit -m "Initial Projects OS setup"
   git branch -M main
   git remote add origin https://github.com/<your-username>/projects-os.git
   git push -u origin main
   ```
2. **Enable GitHub Permissions**:
   - Go to **Settings → Actions → General → Workflow permissions** and select **Read and write permissions**.
   - Go to **Settings → Pages → Build and deployment → Source** and select **GitHub Actions**.
3. **Wait for GitHub Actions (~8–12 min)**:
   - `Build & Release Projects OS ISO` builds `projects-os-x86_64.iso` and publishes it on your **Releases** page.
   - `Deploy Projects OS Website` publishes your landing page to `https://<your-username>.github.io/projects-os/`.
4. **Flash with Rufus on Windows**:
   - Download `projects-os-x86_64.iso` from your repository's **Releases** page.
   - Open **Rufus**, select your **32 GB SanDisk USB drive**, choose `projects-os-x86_64.iso`, and click **START**.
   - **Important**: When prompted, select **"Write in DD Image mode"** so the remaining ~24 GB stays unallocated for automatic 15 GB persistence setup.
5. **Boot**:
   - Plug into your Samsung Galaxy Book 4 (or any PC with Secure Boot disabled) and boot from USB.
   - On first boot, `projects-persist` creates your 15 GB `PROJECTS_PERSIST` partition automatically.
   - Log in (`dev` / password `projects`), pick **Hyprland** or **Niri**, connect to Wi-Fi in the First-Boot Wizard, and choose your project stack.
