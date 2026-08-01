# Unix / Shell Commands

## find & grep

```bash
find . -path ./node_modules -prune -o -name '*.ts' -print  # skip directory
grep -rnwl '<term>' . --include=\*.ts --exclude=\*.{d,test}.ts --exclude-dir={node_modules,dist}  # recursive, whole-word, files-with-matches
```

## curl, ssh & rsync

```bash
curl -fsSL https://example.com/install.sh | bash  # download and run
ssh user@host 'bash -s' < script.sh               # run local script on remote
ssh -L 5432:localhost:5432 user@host              # port forward (local)
ssh -N -D 1080 user@host                          # SOCKS proxy
rsync -avz --progress ./dist/ user@host:/var/www/ # sync directory
```

## processes, disk & logs

```bash
journalctl -u ssh | grep "session opened" -B 1  # successful SSH logins
du -ah . | sort -rh | head -20                  # largest files
lsof -i :8080                                   # who is using port 8080
ps aux | grep '[n]ginx'                         # find process (no grep self-match)
```

## json (jq)

```bash
jq 'sort_by(.id) | sort_keys' new.json > new-sorted.json  # sort for diffing
diff --side-by-side --suppress-common-lines old-sorted.json new-sorted.json | more
```
