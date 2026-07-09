# Vim

## Editing

| command | description |
| ------- | ----------- |
| `yy` | copy current line |
| `dd` | cut/delete current line |
| `p` | paste into next line |

## Line Ranges

| command | description |
| ------- | ----------- |
| `:73,81yank` | copy lines 73 to 81 |
| `:17,39d` | delete/cut lines 17 to 39 |

## Search & Replace

| command | description |
| ------- | ----------- |
| `:%s/<before>/<after>/g` | replace `<before>` with `<after>` in the whole file |

## Files & Splits

| command | description |
| ------- | ----------- |
| `:wq` | save and exit |
| `:e <path/to/file>` | open file from within vim |
| `vim -O <file1> <file2>` | open two files in a vertical split |
| `:vsplit` | split screen vertically |
| `Ctrl+w <arrow-key>` | switch between split-view files |
