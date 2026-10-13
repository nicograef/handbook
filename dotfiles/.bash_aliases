# shellcheck shell=bash
if command -v nvim >/dev/null; then EDITOR=nvim; else EDITOR=nano; fi
export EDITOR VISUAL="$EDITOR"
# pipx, npm and the Claude installer put tools in ~/.local/bin; go install builds into ~/go/bin.
for _p in "$HOME/.local/bin" "$HOME/go/bin"; do
  case ":$PATH:" in *":$_p:"*) ;; *) PATH="$_p:$PATH" ;; esac
done
unset _p
# Go from go.dev's tarball, as on Debian.
if [ -d /usr/local/go/bin ] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then PATH="$PATH:/usr/local/go/bin"; fi

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
# Pull when the branch tracks a remote, then push. Retries once when another machine pushed in between.
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
# pnpm's generated completer rejoins words bash split at ':', so `pnpm run test:u<Tab>` completes.
# Its completion server answers only when the first word is pnpm, so p rewrites it.
if command -v pnpm >/dev/null; then
  eval "$(pnpm completion bash 2>/dev/null)"
  if declare -F _pnpm_completion >/dev/null; then
    _p_complete() {
      COMP_WORDS[0]=pnpm COMP_LINE=${COMP_LINE/p/pnpm} COMP_POINT=$((COMP_POINT + 3))
      _pnpm_completion "$@"
    }
    complete -F _p_complete p
  fi
fi
# make's completer runs its first argument to list targets, so it must get make, not m.
if declare -F _comp_load >/dev/null && _comp_load make; then
  _m_complete() { _comp_cmd_make make "${@:2}"; }
  complete -F _m_complete m
fi
alias puli='pnpm update --latest --interactive'
# Trial upgrade of every dependency, workspace packages included, to its latest version.
# It rewrites every package.json and the lockfile; `git restore` on them plus `pnpm install` undo it.
pci() {
  [ -f package.json ] || { echo 'pci: no package.json here' >&2; return 1; }
  find . -name node_modules -type d -prune -exec rm -rf {} + &&
    rm -f pnpm-lock.yaml &&
    pnpm update -r --latest --ignore-scripts &&
    pnpm audit
}

alias update='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y'

# bat as a colorized cat (apt binary: batcat, cargo binary: bat)
# The ansi theme takes the terminal's palette; delta reads BAT_THEME too.
export BAT_THEME=ansi
command -v batcat >/dev/null && alias bat='batcat'
unalias cat 2>/dev/null
if command -v batcat >/dev/null || command -v bat >/dev/null; then
  # bat drops -n off a terminal and rejects -v, -b and -E, so flags and pipes get GNU cat.
  cat() {
    local a b=bat
    for a; do case $a in -?*) command cat "$@"; return ;; esac; done
    [ -t 1 ] || { command cat "$@"; return; }
    command -v batcat >/dev/null && b=batcat
    command "$b" --paging=never --style=plain "$@"
  }
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
# fzf (>= 0.48 for --bash) adds Ctrl-R, Ctrl-T and **, set up at the first prompt.
# The stock .bashrc re-sources bash-completion after this file, which resets ** on cat, ls and rm.
if command -v fzf >/dev/null; then
  # Later calls return at once: VS Code and bash-preexec eval a copy of PROMPT_COMMAND that still names it.
  unset _fzf_done
  _fzf_init() {
    [ -n "${_fzf_done-}" ] && return
    _fzf_done=1
    eval "$(fzf --bash 2>/dev/null)"
    PROMPT_COMMAND=${PROMPT_COMMAND/_fzf_init/}
  }
  case "${PROMPT_COMMAND:-}" in
    *_fzf_init*) ;;
    *) PROMPT_COMMAND="_fzf_init${PROMPT_COMMAND:+$'\n'$PROMPT_COMMAND}" ;;
  esac
fi

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

# Prompt: path + git branch with dirty state (* modified, + staged); over SSH
# the host leads, coloured as in .tmux.conf: red on *prod*, yellow on *staging*.
# Overrides the stock PS1, which every stock .bashrc sets before sourcing this
# file.
if ! declare -F __git_ps1 >/dev/null; then
  # shellcheck source=/dev/null
  [ -f /usr/lib/git-core/git-sh-prompt ] && . /usr/lib/git-core/git-sh-prompt
fi
if declare -F __git_ps1 >/dev/null; then
  # shellcheck disable=SC2034  # read by __git_ps1
  GIT_PS1_SHOWDIRTYSTATE=1
  _host='' _title='\w'
  if [ -n "${SSH_CONNECTION:-}" ]; then
    case "$HOSTNAME" in *prod*) _c=31 ;; *staging*) _c=33 ;; *) _c=35 ;; esac
    _host="\[\e[1;${_c}m\]\h\[\e[0m\] " _title='\h: \w'
    unset _c
  fi
  PS1="$_host"'\[\e[32m\]\w\[\e[33m\]$(__git_ps1 " (%s)")\[\e[0m\] \$ '
  case "$TERM" in
    xterm*|rxvt*|tmux*|screen*) PS1="\[\e]0;$_title\a\]$PS1" ;;
  esac
  unset _host _title
fi
