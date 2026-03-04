# Unix / Shell Commands

```bash
# search for 'StructuralFormat' recursive, only in .ts files and only print filenames (-l)
grep -rnwl 'StructuralFormat' . --include=\*.ts --exclude=\*.{d,test}.ts --exclude-dir={node_modules,dist}

# show all open ports (sudo necessary to see all PIDs and names)
sudo netstat -tulpn | grep LISTEN

# list successful ssh logins
journalctl -u ssh | grep "session opened" -B 1

# compare large json files
jq 'sort_by(.Buchungsnummer) | sort_keys' new.json > new-sorted.json
jq 'sort_by(.Buchungsnummer) | sort_keys' old.json > old-sorted.json
diff --side-by-side --suppress-common-lines --color=always old-sorted.json new-sorted.json | more

# chunk a file (e.g. into multiples of 500 lines)
split -l 500 -d input.txt input_
