# Infrastructure templates and notes

### hardening new linux server
[secure-linux.md](secure-linux.md)

### .bashrc
```bash
# prompt without [user]:[host] but with git branch in red
PS1='\[\033[01;34m\]\w\[\033[91m\]$(__git_ps1 " %s ")\[\033[00m\]\$ '
```

### docker
on debian 13 (trixie)
https://linuxiac.com/how-to-install-docker-on-debian-13-trixie/
