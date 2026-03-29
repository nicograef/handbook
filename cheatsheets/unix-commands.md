# Unix / Shell Commands

## find

```bash
find . -name '*.md'                              # all markdown files
find . -type f -mtime -7                         # files modified in last 7 days
find . -type f -size +10M                        # files larger than 10 MB
find /var/log -name '*.log' -delete              # delete matching files
find . -name '*.sh' -exec chmod +x {} +          # batch chmod
find . -path ./node_modules -prune -o -name '*.ts' -print  # skip directory
```

## grep

```bash
grep -rnwl 'StructuralFormat' . --include=\*.ts --exclude=\*.{d,test}.ts --exclude-dir={node_modules,dist}
grep -rn 'TODO' --include='*.go'                 # search with line numbers
grep -c 'ERROR' /var/log/syslog                  # count matches
grep -E 'warn|error|fatal' app.log               # extended regex (OR)
grep -v '^#' config.conf | grep -v '^$'          # strip comments + blank lines
```

## sed

```bash
sed -i 's/old/new/g' file.txt                    # in-place replace
sed -n '10,20p' file.txt                         # print lines 10-20
sed '/^$/d' file.txt                             # delete blank lines
sed -i '1i # header' file.txt                    # insert line at top
```

## awk

```bash
awk '{print $1, $3}' file.txt                    # print columns 1 and 3
awk -F: '{print $1}' /etc/passwd                 # custom delimiter
awk '{sum += $1} END {print sum}' numbers.txt    # sum a column
awk 'NR==5,NR==10' file.txt                      # print lines 5-10
docker ps --format '{{.Names}} {{.Status}}' | awk '{print $1}'  # extract names
```

## curl & wget

```bash
curl -fsSL https://example.com/install.sh | bash # download and run
curl -o file.zip https://example.com/file.zip    # save to file
curl -I https://example.com                      # headers only
curl -X POST -H 'Content-Type: application/json' -d '{"key":"val"}' https://api.example.com/endpoint
wget -qO- https://example.com/file.txt           # stdout (like curl -fsSL)
wget --mirror --convert-links https://example.com # offline mirror
```

## ssh & scp

```bash
ssh user@host 'bash -s' < script.sh              # run local script on remote
ssh -L 5432:localhost:5432 user@host              # port forward (local)
ssh -N -D 1080 user@host                         # SOCKS proxy
scp file.txt user@host:/tmp/                     # copy file to remote
scp -r user@host:/var/log/app ./logs             # copy directory from remote
rsync -avz --progress ./dist/ user@host:/var/www/ # sync directory
```

## tar & compression

```bash
tar czf archive.tar.gz dir/                      # create gzipped archive
tar xzf archive.tar.gz                           # extract gzipped archive
tar xzf archive.tar.gz -C /target/dir            # extract to directory
tar tf archive.tar.gz                            # list contents
zip -r archive.zip dir/                          # create zip
unzip archive.zip -d /target/dir                 # extract zip
```

## systemctl

```bash
systemctl status nginx                           # service status
systemctl start|stop|restart nginx               # manage service
systemctl enable --now nginx                     # enable + start at boot
systemctl list-units --type=service --state=running  # running services
systemctl list-timers                            # scheduled timers
journalctl -u nginx --since '1 hour ago'         # recent logs for unit
journalctl -u ssh | grep "session opened" -B 1   # successful SSH logins
```

## disk & processes

```bash
df -h                                            # disk usage by filesystem
du -sh */                                        # directory sizes
du -ah . | sort -rh | head -20                   # largest files
lsof -i :8080                                    # who is using port 8080
ps aux | grep '[n]ginx'                          # find process (no grep self-match)
top -bn1 | head -20                              # snapshot of top processes
free -h                                          # memory usage
```

## networking

```bash
sudo netstat -tulpn | grep LISTEN                # all listening ports
ss -tlnp                                         # same (modern replacement)
ip addr show                                     # list interfaces + IPs
dig +short example.com                           # DNS lookup
curl ifconfig.me                                 # public IP
```

## json (jq)

```bash
jq '.' file.json                                 # pretty-print
jq '.items[] | .name' file.json                  # extract nested field
jq -r '.[] | [.id, .name] | @csv' file.json     # JSON → CSV
jq 'sort_by(.id) | sort_keys' new.json > new-sorted.json           # sort for diffing
diff --side-by-side --suppress-common-lines old-sorted.json new-sorted.json | more
```

## splitting & counting

```bash
split -l 500 -d input.txt input_                 # chunk file into 500-line parts
wc -l file.txt                                   # count lines
wc -l *.go | sort -n                             # lines per file, sorted
sort file.txt | uniq -c | sort -rn               # frequency count
