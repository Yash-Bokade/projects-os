# mkproj: create a new project on the pendrive, npm-init style.
# Asks for details, then creates the folder, git repo, flake.nix, .envrc, README,
# .gitignore, LICENSE and a template, and records name + date in a registry.
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
REGISTRY="$PROJECTS_DIR/.registry.tsv"

die() { printf 'mkproj: %s\n' "$*" >&2; exit 1; }

ask() {
  local prompt="$1" default="${2:-}" reply
  if [ -n "$default" ]; then
    read -r -p "${prompt} (${default}): " reply
  else
    read -r -p "${prompt}: " reply
  fi
  printf '%s' "${reply:-$default}"
}

esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
# Same, but also neutralise ${ so a description cannot inject Nix interpolation.
nesc() { esc "$1" | sed -e 's/\${/\\${/g'; }

mkdir -p "$PROJECTS_DIR"

printf 'This utility walks you through creating a new project in %s\n' "$PROJECTS_DIR"
printf 'Press ^C at any time to quit.\n\n'

name="${1:-}"
[ -n "$name" ] || name="$(ask "project name")"
[[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "name must be lowercase letters, digits, . _ - (and start with a letter or digit)"
[ ! -e "$PROJECTS_DIR/$name" ] || die "$PROJECTS_DIR/$name already exists"

version="$(ask "version" "0.1.0")"
desc="$(ask "description")"
printf 'templates: rust | node | python | elixir | generic\n'
template="$(ask "template" "rust")"
case "$template" in
  rust|node|python|elixir|generic) ;;
  *) die "unknown template: $template" ;;
esac
keywords="$(ask "keywords (comma separated)")"

git_name="$(git config --global user.name 2>/dev/null || true)"
git_mail="$(git config --global user.email 2>/dev/null || true)"
author_default="$git_name${git_mail:+ <$git_mail>}"
author="$(ask "author" "$author_default")"
license="$(ask "license" "MIT")"
repo_url="$(ask "git remote (optional)")"

dir="$PROJECTS_DIR/$name"
cat <<SUMMARY

About to create $dir:
  name:        $name
  version:     $version
  description: $desc
  template:    $template
  keywords:    $keywords
  author:      $author
  license:     $license
  remote:      ${repo_url:--}

SUMMARY
ok="$(ask "Is this OK?" "yes")"
case "${ok,,}" in
  y|yes) ;;
  *) echo "Aborted."; exit 1 ;;
esac

mkdir -p "$dir"
cd "$dir"
created="$(date -Iseconds)"
app="${name//[-.]/_}"
desc_esc="$(esc "$desc")"
desc_nix="$(nesc "$desc")"
author_esc="$(esc "$author")"

# Write stdin to $1 unless that file already exists (a template may have made it).
put() { [ -e "$1" ] || cat > "$1"; }

# Replace @PLACEHOLDERS@ in stdin.
render() {
  local t
  t="$(cat)"
  t="${t//@NAME@/$name}"
  t="${t//@APP@/$app}"
  t="${t//@VERSION@/$version}"
  t="${t//@DESC@/$desc}"
  t="${t//@DESC_ESC@/$desc_esc}"
  t="${t//@DESC_NIX@/$desc_nix}"
  t="${t//@AUTHOR@/$author}"
  t="${t//@AUTHOR_ESC@/$author_esc}"
  t="${t//@LICENSE@/$license}"
  t="${t//@YEAR@/$(date +%Y)}"
  t="${t//@PKGS@/$PKGS}"
  t="${t//@ENV@/$ENVLINES}"
  t="${t//@IGNORE@/$IGNORE}"
  printf '%s\n' "$t"
}

PKGS=""
ENVLINES=""
IGNORE=""

# ---------- per-template files ----------
case "$template" in
  rust)
    PKGS="rustc cargo clippy rustfmt rust-analyzer gcc"
    ENVLINES='RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";'
    IGNORE="target/"
    cargo init --vcs none --name "$name" >/dev/null 2>&1 || die "cargo init failed (is the name a valid crate name?)"
    ;;
  node)
    PKGS="nodejs"
    IGNORE="node_modules/"
    jq -n \
      --arg name "$name" --arg version "$version" --arg desc "$desc" \
      --arg kw "$keywords" --arg author "$author" --arg license "$license" \
      --arg repo "$repo_url" \
      '{name:$name, version:$version, description:$desc, main:"index.js",
        scripts:{start:"node index.js", test:"echo \"Error: no test specified\" && exit 1"},
        keywords:($kw | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))),
        author:$author, license:$license}
       + (if $repo != "" then {repository:{type:"git", url:$repo}} else {} end)' > package.json
    render > index.js <<'EOF'
console.log("hello from @NAME@");
EOF
    ;;
  python)
    PKGS="python3 uv"
    IGNORE=$'__pycache__/\n.venv/\n*.egg-info/'
    mkdir -p "src/$app"
    render > pyproject.toml <<'EOF'
[project]
name = "@NAME@"
version = "@VERSION@"
description = "@DESC_ESC@"
authors = [{ name = "@AUTHOR_ESC@" }]
license = { text = "@LICENSE@" }
requires-python = ">=3.10"

[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"
EOF
    printf '"""@APP@"""\n' | render > "src/$app/__init__.py"
    render > "src/$app/main.py" <<'EOF'
def main() -> None:
    print("hello from @NAME@")


if __name__ == "__main__":
    main()
EOF
    ;;
  elixir)
    PKGS="elixir"
    IGNORE=$'_build/\ndeps/'
    nix shell nixpkgs#elixir --command mix new . --app "$app" >/dev/null || die "mix new failed (app name must start with a letter)"
    ;;
  generic)
    PKGS="git"
    ;;
esac

# ---------- files every project gets ----------
render > flake.nix <<'EOF'
{
  description = "@DESC_NIX@";

  # "nixpkgs" resolves through the system registry, so this project reuses the
  # packages already in the pendrive's /nix/store instead of downloading another copy.
  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [ @PKGS@ ];
          @ENV@
        };
      });
    };
}
EOF

printf 'use flake\n' | put .envrc

{
  printf '.direnv/\nresult\n'
  [ -n "$IGNORE" ] && printf '%s\n' "$IGNORE"
  true
} | put .gitignore

render <<'EOF' | put README.md
# @NAME@

@DESC@

## Develop

```sh
cd ~/Projects/@NAME@
direnv allow     # or: nix develop
```

Version @VERSION@ by @AUTHOR@ (@LICENSE@)
EOF

if [ "$license" = "MIT" ]; then
  render <<'EOF' | put LICENSE
MIT License

Copyright (c) @YEAR@ @AUTHOR@

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
fi

jq -n \
  --arg name "$name" --arg version "$version" --arg desc "$desc" \
  --arg template "$template" --arg author "$author" --arg license "$license" \
  --arg kw "$keywords" --arg created "$created" --arg path "$dir" \
  '{name:$name, version:$version, description:$desc, template:$template,
    author:$author, license:$license,
    keywords:($kw | split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))),
    created:$created, path:$path}' > .project.json

# ---------- git ----------
git init -q -b main
if [ -z "$(git config user.name || true)" ] && [ -n "$author" ]; then
  git config user.name "${author%% <*}"
fi
if [ -z "$(git config user.email || true)" ] && [[ "$author" == *"<"*">"* ]]; then
  mail="${author##*<}"
  git config user.email "${mail%>}"
fi
git add -A
nix flake lock >/dev/null 2>&1 || echo "mkproj: could not lock flake yet (run 'nix flake lock' later)"
git add -A
git -c user.name="${git_name:-${author%% <*}}" -c user.email="${git_mail:-mkproj@localhost}" commit -q -m "Initial commit" || true
if [ -n "$repo_url" ]; then
  git remote add origin "$repo_url"
fi

# ---------- registry (name + date, stored on the pendrive) ----------
printf '%s\t%s\t%s\t%s\n' "$created" "$name" "$template" "$dir" >> "$REGISTRY"

command -v direnv >/dev/null 2>&1 && direnv allow . >/dev/null 2>&1 || true

printf '\nCreated %s\n  cd %s\n' "$name" "$dir"
