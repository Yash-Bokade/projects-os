#!/usr/bin/env bash
# ==========================================================================
#  mkproj — npm-init-style Elixir project creator for the nomad stick
#
#    mkproj            full prompt flow (like npm init)
#    mkproj my_app     same, but the name prompt is pre-filled
#
#  What it does:
#    - asks name / version / description / author / email / license /
#      keywords / elixir version / supervisor / git  (like npm init)
#    - scaffolds with `mix new` on the pendrive
#        (~/Projects on the stick — override with PROJECTS_DIR=/path)
#    - writes flake.nix (dev shell with elixir + elixir-ls) and .envrc
#      — nixpkgs resolves through the OS registry, so it works offline
#    - rewrites README.md with every collected detail + the creation date
#    - appends the project to ~/Projects/.projects.log (name/date/author)
#    - git init -b main, sets project-local identity, first commit
#
#  Everything is stored on the pendrive: ~/Projects lives in your home,
#  which persists once you run `sudo persist-setup` (one time, after
#  first boot) — projects then survive reboots and unplugging the stick.
# ==========================================================================
set -euo pipefail

ACCENT=$'\033[38;2;82;119;195m' # NixOS blue #5277C3
DIM=$'\033[90m'
FG=$'\033[0m'

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

die() { printf '%s\n' "mkproj: $*" >&2; exit 1; }
hi() { printf '%s%s%s\n' "$ACCENT" "$*" "$FG"; }
say() { printf '%s\n' "$*"; }

command -v mix >/dev/null 2>&1 ||
        die "mix not found — elixir ships with this OS, so something is off."
command -v git >/dev/null 2>&1 || die "git not found."

# ---------- prompt helpers ---------------------------------------------------
ask() { # ask VAR "question" "default"
        local __var=$1 __q=$2 __def=${3-} __in=""
        if [[ -n "$__def" ]]; then
                read -r -e -p "$(printf '%s%s%s [%s]: ' "$DIM" "$__q" "$FG" "$__def")" __in || exit 1
                __in="${__in:-$__def}"
        else
                read -r -e -p "$(printf '%s%s%s: ' "$DIM" "$__q" "$FG")" __in || exit 1
        fi
        printf -v "$__var" '%s' "${__in//$'\n'/ }"
}

ask_yn() { # ask_yn VAR "question" 0|1
        local __var=$1 __q=$2 __def=$3 __in __hint="[y/N]"
        [[ "$__def" == "1" ]] && __hint="[Y/n]"
        read -r -e -p "$(printf '%s%s %s%s: ' "$DIM" "$__q" "$__hint" "$FG")" __in || exit 1
        __in="${__in,,}"
        [[ -z "$__in" ]] && __in="$__def"
        case "$__in" in
        1 | y | yes) printf -v "$__var" '%s' "1" ;;
        *) printf -v "$__var" '%s' "0" ;;
        esac
}

normalize_name() {
        printf '%s' "$1" |
                tr '[:upper:]' '[:lower:]' |
                sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

module_name() {
        local out="" part
        local IFS=_
        for part in $1; do out+="${part^}"; done
        printf '%s' "$out"
}

# keep collected strings safe for nix strings, markdown tables and git
clean_text() { printf '%s' "$1" | tr -d '"\\|' | cut -c1-160; }

# ---------- collect answers (npm-init style) ---------------------------------
hi "mkproj — new Elixir project on the nomad stick"
say ""

name_arg="${1-}"
while :; do
        if [[ -n "$name_arg" ]]; then
                raw_name="$name_arg"
                name_arg=""
        else
                ask raw_name "Project name (snake_case)" ""
        fi
        name="$(normalize_name "${raw_name:-}")"
        [[ "$name" =~ ^[a-z][a-z0-9_]*$ ]] && break
        printf '%s\n' "${DIM}  -> use letters/digits/underscores, starting with a letter${FG}"
done
module="$(module_name "$name")"

version="0.1.0"
while :; do
        ask version "Version" "$version"
        [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        printf '%s\n' "${DIM}  -> semantic version, e.g. 0.1.0${FG}"
done

ask description "Description" ""
description="$(clean_text "$description")"

ask author "Author" ""
author="$(clean_text "$author")"

ask email "Author email" ""
email="$(clean_text "$email")"

ask license "License" "MIT"
license="$(clean_text "$license")"

ask keywords "Keywords (comma separated)" ""
keywords="$(clean_text "$keywords")"

system_elixir="$(elixir -e 'IO.puts System.version()' 2>/dev/null || echo unknown)"
elixir_attr="beamPackages.elixir"
elixir_note="system default (pkgs.elixir)"
while :; do
        ask elixir_in "Elixir version ('system' or e.g. 1.19)" "system"
        case "${elixir_in,,}" in
        system) break ;;
        1.[0-9]*)
                elixir_attr="elixir_${elixir_in//./_}"
                elixir_note="pinned (pkgs.${elixir_attr})"
                break
                ;;
        *) printf '%s\n' "${DIM}  -> 'system' or a version like 1.19${FG}" ;;
        esac
done

ask_yn with_sup "Include an OTP supervisor (--sup)?" 0
ask_yn with_git "Initialize a git repository?" 1

# ---------- confirm ----------------------------------------------------------
today="$(date +%Y-%m-%d)"
project_dir="${PROJECTS_DIR%/}/$name"
email_extra=""
[[ -n "$email" ]] && email_extra=" <$email>"

hi "──────────────────────────────────────────────"
printf '  %-13s%s\n' "name:" "$name"
printf '  %-13s%s\n' "module:" "$module"
printf '  %-13s%s\n' "version:" "$version"
printf '  %-13s%s\n' "description:" "${description:--}"
printf '  %-13s%s\n' "author:" "${author:--}${email_extra}"
printf '  %-13s%s\n' "license:" "$license"
printf '  %-13s%s\n' "keywords:" "${keywords:--}"
printf '  %-13s%s\n' "elixir:" "$elixir_note (now: $system_elixir)"
printf '  %-13s%s\n' "supervisor:" "$([[ "$with_sup" == 1 ]] && echo yes || echo no)"
printf '  %-13s%s\n' "git:" "$([[ "$with_git" == 1 ]] && echo yes || echo no)"
printf '  %-13s%s\n' "location:" "$project_dir"
printf '  %-13s%s\n' "created:" "$today"
hi "──────────────────────────────────────────────"

ok="yes"
ask ok "Is this OK?" "yes"
[[ "$ok" =~ ^[Yy] ]] || die "aborted — nothing was written."

# ---------- scaffold ---------------------------------------------------------
mkdir -p "$PROJECTS_DIR"
[[ -e "$project_dir" ]] && die "$project_dir already exists."

sup_args=()
[[ "$with_sup" == 1 ]] && sup_args+=(--sup)

cd "$PROJECTS_DIR"
mix new "$name" "${sup_args[@]}" || die "mix new failed"
cd "$name"

# mix.exs: carry the chosen version into the scaffold
sed -i "s/version: \"[0-9.]*\"/version: \"$version\"/" mix.exs

# ---------- flake.nix --------------------------------------------------------
# Quoted heredoc: nothing is expanded here, placeholders are swapped below.
flake_tpl=$(cat <<'NIXEOF'
{
  description = "@DESC@";

  # @NAME@ @VERSION@ — created @TODAY@ by @AUTHOR@@EMAILEXTRA@
  # License: @LICENSE@ | Keywords: @KEYWORDS@ | Elixir: @ELIXIR_NOTE@
  #
  # nixpkgs has no pinned URL on purpose: it resolves through this OS's
  # global registry (nix.registry.nixpkgs in shared.nix), so
  # `nix develop` works offline and matches the system's nixpkgs exactly.
  # To pin this project independently, add:
  #   inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: {
    devShells.${builtins.currentSystem}.default =
      let
        pkgs = nixpkgs.legacyPackages.${builtins.currentSystem};
      in
      pkgs.mkShell {
        name = "@NAME@";
        packages = with pkgs; [
          @ELIXIR_ATTR@ # elixir + erlang/otp
          elixir-ls
        ];
        shellHook = ''
          echo "@NAME@ @VERSION@ — @DESC@"
          echo "elixir: $(elixir -e 'IO.puts System.version()' 2>/dev/null || echo n/a) | created @TODAY@ | license @LICENSE@"
        '';
      };
  };
}
NIXEOF
)

fl="$flake_tpl"
fl="${fl//@NAME@/$name}"
fl="${fl//@DESC@/$description}"
fl="${fl//@VERSION@/$version}"
fl="${fl//@AUTHOR@/${author:-unknown}}"
fl="${fl//@EMAILEXTRA@/$email_extra}"
fl="${fl//@LICENSE@/$license}"
fl="${fl//@KEYWORDS@/${keywords:--}}"
fl="${fl//@TODAY@/$today}"
fl="${fl//@ELIXIR_NOTE@/$elixir_note}"
fl="${fl//@ELIXIR_ATTR@/$elixir_attr}"
printf '%s\n' "$fl" > flake.nix

# ---------- .envrc + gitignore -----------------------------------------------
cat > .envrc <<'EOF'
use flake
watch_file mix.exs
EOF

grep -q '/.direnv/' .gitignore || printf '\n# direnv\n/.direnv/\n' >> .gitignore

# ---------- README.md with the collected details -----------------------------
readme_tpl=$(cat <<'MDEOF'
# @NAME@

@DESC@

| | |
|---|---|
| **Version** | @VERSION@ |
| **Module** | `@MODULE@` |
| **Author** | @AUTHOR@@EMAILEXTRA@ |
| **License** | @LICENSE@ |
| **Keywords** | @KEYWORDS@ |
| **Elixir** | @ELIXIR_NOTE@ |
| **Created** | @TODAY@ |
| **Storage** | nomad pendrive — `$PROJECTS_DIR` (override with the `PROJECTS_DIR` env var) |

## Develop

```bash
direnv allow      # once — activates the flake dev shell whenever you cd in
mix deps.get
mix test
```

The dev environment lives in `flake.nix` and is auto-entered by direnv;
without direnv: `nix develop`.

## Registry note

Projects created on the nomad stick resolve `nixpkgs` through the system
registry, so the dev shell matches the OS packages and works offline.
This file (`@LOGPATH@`) logs every project created on this stick.
MDEOF
)

log_path="${PROJECTS_DIR%/}/.projects.log"
rd="$readme_tpl"
rd="${rd//@NAME@/$name}"
rd="${rd//@MODULE@/$module}"
rd="${rd//@DESC@/${description:-}}"
rd="${rd//@VERSION@/$version}"
rd="${rd//@AUTHOR@/${author:-unknown}}"
rd="${rd//@EMAILEXTRA@/$email_extra}"
rd="${rd//@LICENSE@/$license}"
rd="${rd//@KEYWORDS@/${keywords:--}}"
rd="${rd//@ELIXIR_NOTE@/$elixir_note}"
rd="${rd//@TODAY@/$today}"
rd="${rd//@LOGPATH@/$log_path}"
printf '%s\n' "$rd" > README.md

# ---------- the projects log lives on the pendrive ---------------------------
printf '%s | %s | v%s | %s | %s\n' "$today" "$name" "$version" "${author:-unknown}" "${description:-}" >> "$log_path"

# ---------- git ---------------------------------------------------------------
if [[ "$with_git" == 1 ]]; then
        git init -b main >/dev/null
        [[ -n "$author" ]] && git config user.name "$author"
        [[ -n "$email" ]] && git config user.email "$email"
        git add -A
        if git commit -q -m "chore: initialize $name v$version ($today)"; then
                hi "git: repository initialized, first commit created"
        else
                printf '%s\n' "${DIM}git: commit skipped — set user.name / user.email and commit by hand${FG}"
        fi
fi

# ---------- lock the dev shell (works offline via the system registry) --------
if command -v nix >/dev/null 2>&1; then
        if nix flake lock >/dev/null 2>&1; then
                hi "nix: flake.lock written — dev shell ready"
        else
                printf '%s\n' "${DIM}nix: lock skipped (offline?) — run 'nix flake lock' next time you are online${FG}"
        fi
fi

hi "──────────────────────────────────────────────"
printf '  %-10s%s\n' "created:" "$PWD"
printf '  %-10s%s\n' "next:" "direnv allow   (then just cd around)"
printf '  %-10s%s\n' "then:" "mix deps.get   mix test   iex -S mix"
hi "──────────────────────────────────────────────"
