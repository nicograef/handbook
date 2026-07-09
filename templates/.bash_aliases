alias ll='ls -la'
alias la='ls -A'
# Start ssh-agent only if none is reachable (ssh-add -l exit code 2 = no
# agent), then add keys — reuses the same agent across shells/sourcing.
sss() {
  ssh-add -l >/dev/null 2>&1
  if [ "$?" -eq 2 ]; then
    eval "$(ssh-agent)" >/dev/null
  fi
  ssh-add
}
alias gfp='git fetch --prune && git pull'
alias gct='git checkout test'
alias gcm='git checkout main || git checkout master'
alias gbv='git branch -vv'
alias glo='git log --oneline'
alias glg='git log --graph --pretty=oneline --abbrev-commit --branches'
alias p='pnpm'
alias m='make'
alias puli='pnpm update --latest --interactive'
alias pci='rm -rf node_modules/ && rm -rf pnpm-lock.yaml && rm -rf $(pnpm store path) && pnpm update --latest --ignore-scripts && pnpm audit'
alias diffi='diff --side-by-side --suppress-common-lines --color=always'

# Modern CLI tools – only activate when the tool is actually installed,
# so this stays safe in Codespaces and minimal machines.
# bat as a colorized cat (apt binary: batcat, cargo binary: bat)
if command -v batcat >/dev/null; then
  alias cat='batcat --paging=never --style=plain'
  alias bat='batcat'
elif command -v bat >/dev/null; then
  alias cat='bat --paging=never --style=plain'
fi
# eza as an ls replacement with a git column (ll/la inherit this)
command -v eza >/dev/null && alias ls='eza --group-directories-first --git'
# fzf: Ctrl-R fuzzy history, Ctrl-T insert file
if command -v fzf >/dev/null; then
  for _f in /usr/share/doc/fzf/examples/key-bindings.bash \
            /usr/share/bash-completion/completions/fzf \
            "$HOME/.fzf/shell/key-bindings.bash"; do
    [ -f "$_f" ] && source "$_f"
  done
  unset _f
fi
