const GITHUB_REPO = "__GITHUB_REPO__";

const SHORTCUTS = [
  { key: "Super + S", action: "Toggle hidden System Resources Monitor (btop)", cat: "System" },
  { key: "Super + D", action: "Hide all open windows / Restore minimized windows", cat: "System" },
  { key: "Super + /", action: "Open searchable Shortcuts menu (Fuzzel)", cat: "System" },
  { key: "Super + ,", action: "Open Projects OS Settings GUI (Native C)", cat: "System" },
  { key: "Super + Shift + R", action: "Project Reset (keeps Wi-Fi, SSH, OS settings)", cat: "System" },
  { key: "Super + Return", action: "Launch Terminal (Foot)", cat: "Apps" },
  { key: "Super + Space", action: "Application Launcher (Fuzzel)", cat: "Apps" },
  { key: "Super + B", action: "Launch Minimal Firefox", cat: "Apps" },
  { key: "Super + N", action: "Launch Neovim (LazyVim)", cat: "Apps" },
  { key: "Super + L", action: "Launch LocalSend (LAN File Sharing)", cat: "Apps" },
  { key: "Super + O", action: "Launch OBS Studio", cat: "Apps" },
  { key: "Super + Q", action: "Close focused window", cat: "Windows" },
  { key: "Super + M", action: "Exit session back to Hyprland / Niri switcher", cat: "Windows" },
  { key: "Space + f + f", action: "LazyVim: Find files in project", cat: "Neovim" },
  { key: "Space + s + g", action: "LazyVim: Live grep across project", cat: "Neovim" },
  { key: "Space + g + g", action: "LazyVim: Open LazyGit", cat: "Neovim" },
];

const VIEWS = {
  hyprland: {
    mode: "HYPRLAND",
    cls: "desktop-canvas grid-2",
    html: `
      <div class="win focused">
        <div class="win-bar"><span>nvim — ~/Projects/api/Main.java (LazyVim + jdtls)</span><span>Hyprland Tile</span></div>
        <div class="win-body"> 1  public class Main {
 2      public static void main(String[] args) {
 3          System.out.println("Projects OS — Ready!");
 4      }
 5  }
 ~
 -- NORMAL --  jdtls ✓  mise: java@latest</div>
      </div>
      <div class="win">
        <div class="win-bar"><span>foot — ~/Projects/api</span><span>bash</span></div>
        <div class="win-body">projects-os api ❯ file /usr/local/bin/projects-settings
ELF 64-bit LSB pie executable, x86-64, stripped

projects-os api ❯ which python
which: no python in PATH (Zero Python OS!)</div>
      </div>`
  },
  niri: {
    mode: "NIRI SCROLLABLE",
    cls: "desktop-canvas grid-niri",
    html: `
      <div class="win focused">
        <div class="win-bar"><span>nvim — main.rs (rust-analyzer)</span><span>Col 1</span></div>
        <div class="win-body">fn main() {
    println!("Infinite horizontal tiling!");
}</div>
      </div>
      <div class="win">
        <div class="win-bar"><span>Firefox (Minimal Chrome)</span><span>Col 2</span></div>
        <div class="win-body">https://docs.rs/tokio
──────────────────────────
Zero toolbar clutter.
Hardware VA-API Wayland.</div>
      </div>
      <div class="win">
        <div class="win-bar"><span>LocalSend</span><span>Col 3 →</span></div>
        <div class="win-body">Ready on LAN
Port 53317</div>
      </div>`
  },
  wizard: {
    mode: "FIRST-BOOT WIZARD (C11 ELF)",
    cls: "desktop-canvas",
    html: `
      <div class="win focused" style="max-width: 560px; margin: 0 auto; width: 100%;">
        <div class="win-bar"><span>Projects OS — First-Boot Project Stack Wizard</span><span>Native C + GTK4</span></div>
        <div class="win-body">[1] Connectivity: Online (Wi-Fi 6E connected)

[2] Select Language Stacks for this Project:
  [x] Java (Latest OpenJDK)   [x] C / C++ (Clang+CMake)
  [ ] Rust (Latest)           [ ] Go (Latest)
  [ ] Node.js + TypeScript    [ ] Zig (Latest)

$ mise use -g java@latest
$ nvim --headless "+Lazy! sync" +qa
✓ LazyVim extras & Mason LSPs ready!</div>
      </div>`
  },
  settings: {
    mode: "SETTINGS GUI (C11 ELF)",
    cls: "desktop-canvas",
    html: `
      <div class="win focused" style="max-width: 600px; margin: 0 auto; width: 100%;">
        <div class="win-bar"><span>Projects OS Settings (Super + ,)</span><span>Native C + GTK4</span></div>
        <div class="win-body">Tabs: [Themes & UI]  [Hotkeys]  [Data Export Paths]  [Project Reset]

• Config Backend:  ~/.config/projects-os/settings.conf (GLib GKeyFile + Bash)
• Theme:           Matte Dark (Zero Wallpaper Bloat)
• OBS Recordings:  /home/dev/Exports/OBS
• Persistence:     /persist (14.2 GB free / 15.0 GB)

[ Reset Project Environment ]  (Preserves Wi-Fi, SSH keys & Settings)</div>
      </div>`
  }
};

function renderView(name) {
  const v = VIEWS[name] || VIEWS.hyprland;
  const canvas = document.getElementById("desktop-canvas");
  canvas.className = v.cls;
  canvas.innerHTML = v.html;
  document.getElementById("wb-mode-label").textContent = v.mode;
  document.querySelectorAll(".chip[data-view]").forEach(btn => {
    btn.classList.toggle("active", btn.dataset.view === name);
  });
}

function renderShortcuts(filter = "") {
  const list = document.getElementById("shortcuts-list");
  const q = filter.toLowerCase();
  const items = SHORTCUTS.filter(s =>
    s.key.toLowerCase().includes(q) || s.action.toLowerCase().includes(q) || s.cat.toLowerCase().includes(q)
  );
  list.innerHTML = items.map(s => `
    <div class="sc-row">
      <span>${s.action}</span>
      <span class="sc-key">${s.key}</span>
    </div>
  `).join("");
}

async function loadLatestRelease() {
  if (!GITHUB_REPO || GITHUB_REPO.includes("__GITHUB_REPO__")) return;
  try {
    const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/releases/latest`);
    if (!res.ok) return;
    const rel = await res.json();
    const iso = (rel.assets || []).find(a => a.name.endsWith(".iso"));
    const relLink = document.getElementById("release-link");
    relLink.href = rel.html_url;
    if (iso) {
      const sizeGB = (iso.size / (1024 ** 3)).toFixed(2);
      const dlBtn = document.getElementById("iso-download-btn");
      const navBtn = document.getElementById("nav-download");
      dlBtn.href = iso.browser_download_url;
      dlBtn.textContent = `Download ISO (${sizeGB} GB)`;
      navBtn.href = iso.browser_download_url;
      document.getElementById("release-meta").textContent =
        `Latest Release: ${rel.tag_name} • ${iso.name} (${sizeGB} GB) • Ready for Rufus DD Mode`;
    }
  } catch (e) {
    console.warn("Could not fetch GitHub release metadata:", e);
  }
}

document.querySelectorAll(".chip[data-view]").forEach(btn => {
  btn.addEventListener("click", () => renderView(btn.dataset.view));
});

const sysmonModal = document.getElementById("sysmon-modal");
document.getElementById("toggle-sysmon-demo").addEventListener("click", () => {
  sysmonModal.classList.toggle("hidden");
});
document.getElementById("close-sysmon").addEventListener("click", () => {
  sysmonModal.classList.add("hidden");
});
document.getElementById("shortcut-search").addEventListener("input", e => {
  renderShortcuts(e.target.value);
});

renderView("hyprland");
renderShortcuts();
loadLatestRelease();
