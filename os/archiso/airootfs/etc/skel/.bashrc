# Projects OS minimal shell config
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"
export MOZ_ENABLE_WAYLAND=1

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

alias ll='ls -lah --color=auto'
alias v='nvim'
alias shortcuts='cat ~/SHORTCUTS.txt'
alias proj-reset='/usr/local/bin/projects-reset'
alias proj-settings='/usr/local/bin/projects-settings'
alias proj-wizard='/usr/local/bin/projects-wizard'

PS1='\[\e[38;5;75m\]projects-os\[\e[0m\] \[\e[1m\]\W\[\e[0m\] ❯ '
