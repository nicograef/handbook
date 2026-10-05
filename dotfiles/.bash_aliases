# shellcheck shell=bash
if command -v nvim >/dev/null; then EDITOR=nvim; else EDITOR=nano; fi
export EDITOR VISUAL="$EDITOR"

# The stock .bashrc loads bash-completion only after this file; fzf and the m
# completer below need it now.
if ! declare -F _comp_load >/dev/null && ! declare -F _completion_loader >/dev/null; then
  for _bc in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
    # shellcheck source=/dev/null
    [ -r "$_bc" ] && { . "$_bc"; break; }
  done
  unset _bc
fi

alias gfp='git pull --all'
# Pull (rebase + autostash from install-dotfiles.sh) when the branch tracks a
# remote, then push. Retries once when another machine pushed in between.
gfpp() {
  if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    git pull --all || return
  fi
  git push || { git pull && git push; }
}
alias gp='git push'
alias gs='git status'
alias gd='git diff'
alias gcm='git switch main'
alias gbv='git branch -vv'
alias gba='git branch -vva'
alias glo="git log --pretty=format:'%C(yellow)%h%C(reset) %C(green)(%ar)%C(reset) %s'"
alias glg="git log --graph --all --pretty=format:'%C(yellow)%h%C(reset) %C(auto)%d%C(reset) %s %C(green)(%ar)%C(reset)'"

alias p='pnpm'
alias m='make'
# pnpm ships no bash-completion file; this calls its completion server for p and pnpm.
_pnpm_complete() {
  mapfile -t COMPREPLY < <(COMP_LINE="$COMP_LINE" COMP_POINT="$COMP_POINT" SHELL=bash \
    pnpm completion-server -- "${COMP_WORDS[@]}")
}
complete -F _pnpm_complete p pnpm
# make's completer runs its first argument to list targets, so it must get make, not m.
if declare -F _comp_load >/dev/null && _comp_load make; then
  _m_complete() { _comp_cmd_make make "${@:2}"; }
  complete -F _m_complete m
fi
alias puli='pnpm update --latest --interactive'
# Trial upgrade of every dependency to its latest version; git restores the lockfile.
pci() {
  [ -f package.json ] || { echo 'pci: no package.json here' >&2; return 1; }
  find . -name node_modules -type d -prune -exec rm -rf {} + &&
    rm -f pnpm-lock.yaml &&
    pnpm update --recursive --latest --ignore-scripts &&
    pnpm audit
}

alias update='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'

# Modern CLI tools – only activate when the tool is actually installed,
# so this stays safe on minimal machines.
# bat as a colorized cat (apt binary: batcat, cargo binary: bat)
if command -v batcat >/dev/null; then
  alias cat='batcat --paging=never --style=plain'
  alias bat='batcat'
elif command -v bat >/dev/null; then
  alias cat='bat --paging=never --style=plain'
fi
# eza for ll/la only: plain ls keeps GNU flags (eza's -t takes a field, -h is header).
if command -v eza >/dev/null; then
  alias ll='eza -la --group-directories-first --git'
  alias la='eza -a --group-directories-first'
else
  alias ll='ls -la'
  alias la='ls -A'
fi
# fd under its real name (Debian/Ubuntu package fd-find installs it as fdfind)
if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  alias fd='fdfind'
fi
if command -v delta >/dev/null; then
  alias diffi='delta --side-by-side'
else
  alias diffi='diff --side-by-side --suppress-common-lines --color=always'
fi
# fzf: Ctrl-R history, Ctrl-T files, ** completion. fzf < 0.48 lacks --bash and skips.
command -v fzf >/dev/null && eval "$(fzf --bash 2>/dev/null)"

# The stock .bashrc sets HISTFILESIZE=2000 before sourcing this file, and bash
# truncates HISTFILE on that assignment. A separate file escapes the cut.
mkdir -p "$HOME/.local/state"
HISTFILE="$HOME/.local/state/bash_history"
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
# file.
if ! declare -F __git_ps1 >/dev/null; then
  # shellcheck source=/dev/null
  [ -f /usr/lib/git-core/git-sh-prompt ] && . /usr/lib/git-core/git-sh-prompt
fi
if declare -F __git_ps1 >/dev/null; then
  # shellcheck disable=SC2034  # read by __git_ps1
  GIT_PS1_SHOWDIRTYSTATE=1
  PS1='\[\e[32m\]\w\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\] \$ '
  # terminal window title: path only
  case "$TERM" in
    xterm*|rxvt*|tmux*|screen*) PS1="\[\e]0;\w\a\]$PS1" ;;
  esac
fi
