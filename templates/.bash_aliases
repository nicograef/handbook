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
# fd under its real name (Debian/Ubuntu package fd-find installs it as fdfind)
if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  alias fd='fdfind'
fi
# fzf: Ctrl-R fuzzy history, Ctrl-T insert file, ** fuzzy completion.
# The stock Ubuntu .bashrc sources this file BEFORE enabling bash-completion, so
# load bash-completion here first: fzf only *wraps* an existing completion (e.g.
# git's) when _completion_loader already exists — otherwise it clobbers git with
# plain path completion. bash-completion is idempotent, so .bashrc's later load
# is a harmless no-op.
if command -v fzf >/dev/null; then
  if ! declare -F _completion_loader >/dev/null; then
    for _bc in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
      [ -r "$_bc" ] && { . "$_bc"; break; }
    done
    unset _bc
  fi
  for _f in /usr/share/doc/fzf/examples/key-bindings.bash \
            /usr/share/bash-completion/completions/fzf \
            "$HOME/.fzf/shell/key-bindings.bash"; do
    [ -f "$_f" ] && source "$_f"
  done
  unset _f
fi

# History: bigger, timestamped, shared across terminals immediately.
# Sourced after the stock .bashrc history block, so these settings win.
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T '
shopt -s histappend histverify
# Append each command to the history file as it runs (guard keeps re-sourcing
# from stacking duplicate hooks).
case "${PROMPT_COMMAND:-}" in
  *"history -a"*) ;;
  *) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a" ;;
esac

# Prompt: path + git branch with dirty state (* modified, + staged).
# Overrides the stock PS1, which every stock .bashrc sets before sourcing this
# file. Skipped when no git prompt helper is available.
if ! declare -F __git_ps1 >/dev/null; then
  [ -f /usr/lib/git-core/git-sh-prompt ] && . /usr/lib/git-core/git-sh-prompt
fi
if declare -F __git_ps1 >/dev/null; then
  GIT_PS1_SHOWDIRTYSTATE=1
  PS1='\[\e[32m\]\w\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\] \$ '
  # terminal window title: path only
  case "$TERM" in
    xterm*|rxvt*|tmux*|screen*) PS1="\[\e]0;\w\a\]$PS1" ;;
  esac
fi
