# ~/.bashrc – custom prompt & aliases

# prompt: working dir (blue) + git branch (red)
PS1='\[\033[01;34m\]\w\[\033[91m\]$(__git_ps1 " %s ")\[\033[00m\]\$ '
