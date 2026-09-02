# Unix / Shell Commands

## find & grep

```bash
find . -path ./node_modules -prune -o -name '*.ts' -print  # skip directory
```

## processes, disk & logs

```bash
ps aux | grep '[n]ginx'                         # find process (no grep self-match)
```

## json (jq)

```bash
jq -S 'sort_by(.id)' new.json > new-sorted.json  # sort for diffing
diff --side-by-side --suppress-common-lines old-sorted.json new-sorted.json | more
```
