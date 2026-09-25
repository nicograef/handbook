# Lane briefs

Two files per wave under `../<repo>-wt/w<wave>/`: `common.md` for every lane and `<lane>/brief.md` per lane. The agent's prompt names both paths and nothing else; a pasted brief changes with every edit, a path does not.

## common.md

| Section | Says |
| --- | --- |
| Where you work | the worktree path and branch; every command runs there; a command run without the lane's ports and env reaches the main checkout's store; the data directory's symlinks and real directories; the repo's own rules bind, plus staging by path |
| Spend | nothing reaches a paid provider unless the brief names the row and the owner's yes; the paid targets by name; the free instruments that prove a criterion instead; a needed paid run goes under "for the owner" with its list-price projection |
| Long work | every job over a few minutes runs as a `systemd-run --user` unit with its log under the wave directory; the gate runs under the host-wide `flock` with capped workers; one gate per lane at a time |
| Commits | one per phase or coherent step; every figure the plan wants goes in the body verbatim; tick the plan's boxes in the commit that meets them; lint and targeted tests before each commit, the full gate once at the end |
| Migrations | the reserved numbers by phase; every registry the repo keeps beside the migration files; a number nobody reserved is taken as the next free one and reported |
| Ownership | the wave's ownership rows; a needed change in another lane's file goes in its own `<phase>: needs <file>` commit |
| What you do not do | no rebase, merge, landing or push; no questions to the user; no bus; no subagents unless the brief names an agent type; no stopping after one phase, the group is the unit |
| Report | the file path to write it to and the sections: commits, criteria with met or unmet and the evidence, gate tail with its log path, decisions taken, for the owner, left open |

## brief.md

- Lane path, branch, store and service ports, what the store carries and how it was verified.
- The phases in order, each in one sentence naming its deliverable, with the plan file as the source of criteria.
- The rulings the user gave that this lane carries, so the agent does not re-open them.
- What another lane of the wave will add on top of this lane's files, so interfaces stay where they are.
- The files the lane owns and the files it must not edit, both by path.
- Which criteria are proven with fakes and which paid row is projected instead of bought.
