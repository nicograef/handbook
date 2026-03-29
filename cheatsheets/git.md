# Git

## Basics

```bash
git status                                       # working tree status
git diff                                         # unstaged changes
git diff --staged                                # staged changes
git add -p                                       # interactive staging (hunk by hunk)
git commit -m 'feat: add endpoint'               # conventional commit
git commit --amend --no-edit                     # amend last commit (keep message)
```

## Branches

```bash
git branch                                       # list local branches
git branch -a                                    # list all (incl. remote)
git switch feature-x                             # switch branch
git switch -c feature-x                          # create + switch
git branch -d feature-x                          # delete (safe — merged only)
git branch -D feature-x                          # force delete
git push origin --delete feature-x               # delete remote branch
```

## Stashing

```bash
git stash                                        # stash working changes
git stash -u                                     # include untracked files
git stash list                                   # list stashes
git stash pop                                    # apply + remove latest stash
git stash apply stash@{2}                        # apply specific stash
git stash drop stash@{0}                         # remove specific stash
```

## Rebasing

```bash
git rebase main                                  # rebase current branch onto main
git rebase -i HEAD~3                             # interactive rebase (last 3 commits)
git rebase --abort                               # cancel in-progress rebase
git rebase --continue                            # after resolving conflicts
```

Interactive rebase keywords: `pick`, `reword`, `squash`, `fixup`, `drop`.

## Log & History

```bash
git log --oneline -20                            # compact log (last 20)
git log --oneline --graph --all                  # visual branch graph
git log --author='Nico' --since='1 week ago'     # filter by author + date
git log -p -- path/to/file                       # full diff history of file
git log --stat                                   # files changed per commit
git shortlog -sn                                 # commits per author
git blame file.go                                # line-by-line authorship
```

## Undoing

```bash
git restore file.go                              # discard unstaged changes
git restore --staged file.go                     # unstage file
git reset --soft HEAD~1                          # undo last commit (keep changes staged)
git reset --mixed HEAD~1                         # undo last commit (keep changes unstaged)
git revert <commit>                              # create inverse commit (safe for shared history)
```

## Remote

```bash
git remote -v                                    # list remotes
git fetch --prune                                # fetch + remove stale tracking branches
git pull --rebase                                # pull with rebase (linear history)
git push -u origin feature-x                     # push + set upstream
```

## Tags

```bash
git tag v1.0.0                                   # lightweight tag
git tag -a v1.0.0 -m 'release 1.0.0'            # annotated tag
git push origin v1.0.0                           # push single tag
git push origin --tags                           # push all tags
git tag -d v1.0.0                                # delete local tag
```

## Cherry-Pick

```bash
git cherry-pick <commit>                         # apply single commit
git cherry-pick <a>..<b>                         # apply range (exclusive a)
git cherry-pick --abort                          # cancel
```

## Useful Aliases

```bash
git config --global alias.co 'checkout'
git config --global alias.sw 'switch'
git config --global alias.st 'status -sb'
git config --global alias.lg 'log --oneline --graph --all'
git config --global alias.uncommit 'reset --soft HEAD~1'
```

## Cleanup

```bash
git gc                                           # garbage collect
git prune                                        # remove unreachable objects
git clean -fd                                    # remove untracked files + dirs
git clean -fdn                                   # dry-run (preview only)
```
