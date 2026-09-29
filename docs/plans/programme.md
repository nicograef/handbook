# Programme: Handbook Restructure

Plans: structure (S, landed and removed), `plan-handbook-journeys.md` (J), `plan-handbook-agent-layer.md` (A). Phase ids below are plan letter plus phase number.

## Rule

- Interleave where files are disjoint; one owner per shared file per wave.
- The group is the unit of gate, review and landing.
- Long work (Docker builds) runs detached under `systemd-run --user`; every gate runs under `flock /tmp/handbook-gate.lock`.
- The owner reads only spend rows and irreversible diffs. This programme has neither: no paid provider, and every change is a git commit.
- Status lives here only. Lanes never tick plan boxes; the lead ticks them in the landing commit from the lane's report.
- `install.sh` runs only in `~/r/handbook` on `main`, by the lead (S9).
- The agent-layer lane lands last, because `claude/settings.json`, `claude/CLAUDE.md` and the skills go live in every session at landing.

## Waves and lanes

| Wave | Lane | Phases in order | Waits for | Store | Detached jobs | Landing slot |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `project-gate` | J3 | nothing | none | actionlint container | 1 |
| 1 | `structure` | S1, S2, S3, S4, S5, S6, S7, S8 | nothing | none | none | 2, then the lead runs S9 on `main` |
| 2 | `journeys-core` | J1, J2 | wave 1 landed, S9 done | none | `make test-dockerfiles` | 1 |
| 3 | `new-project` | J4 | wave 2 | none | none | 1 |
| 3 | `deploy` | J5 | wave 2 | none | none | 2 |
| 3 | `backup` | J6 | wave 2 | none | none | 3 |
| 3 | `server-upkeep` | J7 | wave 2 | none | none | 4 |
| 3 | `monitoring` | J8 | wave 2 | none | none | 5 |
| 3 | `dev-machine` | J9 | wave 2 | none | none | 6 |
| 3 | `agent-layer` | A1, A2, A3, A4 | wave 2 | none | `claude -p` probe | last of the programme |
| 4 | `linux-services` | J10 | wave 3 journeys lanes | none | none | 1, before `agent-layer` |

The agent-layer plan asks for a start after journeys has landed. Its files are disjoint from J4 to J10, and A4 needs only J2's writing rules. So it runs in wave 3 from the wave-2 base and lands after J10, which keeps the plan's live-config constraint.

## Ownership

| File | Owner | What the other lane adds at its rebase |
| --- | --- | --- |
| `.claude/skills/programme/SKILL.md` | `structure` (S1, step 6 call path) | `agent-layer` (A2) rebases onto it in wave 3; S lands two waves earlier |
| `claude/settings.json` | `structure` (S1, S7 allow entries) | `agent-layer` (A1) builds on the landed file |
| `README.md`, `Makefile` | `structure` in wave 1, `journeys-core` in wave 2, `linux-services` in wave 4 | no two lanes of one wave write them |
| `guides/provision-server.md`, `guides/maintenance.md`, `guides/deploy.md` | `server-upkeep` (J7) and `deploy` (J5) in wave 3 | `linux-services` (J10) adds its links in wave 4 |
| `docs/plans/*.md` | the lead | lanes report criteria; the lead ticks at landing |

## Landing a group

1. `~/.claude/agent-bus.sh radar`; a peer conflict is settled by landing order, the later lane rebasing.
2. Rebase the lane onto `main`. Docs-only rebases rerun `make check`; a rebase that brings scripts reruns the lane's full criteria.
3. The gate runs on the lane under the host-wide lock: `flock /tmp/handbook-gate.lock make check`. Green means a complete run.
4. One review of the group's diff on `opus`; findings verified before any is applied.
5. `git merge --ff-only` on `main`, push, send `landed` on the bus. The same commit ticks the plan boxes and flips the status rows below.
6. `git worktree remove` the lane and `git branch -d` it.

## Stores and lanes

- Worktree: `git worktree add ../handbook-wt/<lane> -b prog/<lane> main`.
- Briefs, reports and reviews: `../handbook-wt/w<wave>/`.
- No database, ports or env. Docker image and container names carry the lane name, so two lanes never collide.

## Migrations

None.

## Spend

None.

## Status

| Phase | Lane | Wave | Status | Landed sha |
| --- | --- | --- | --- | --- |
| J3 | `project-gate` | 1 | landed | d807182 |
| S1–S8 | `structure` | 1 | landed | ddbb63a |
| S9 | lead on `main` | 1 | done | c4cf2e8 |
| J1, J2 | `journeys-core` | 2 | landed | e021c64 |
| J4 | `new-project` | 3 | open | |
| J5 | `deploy` | 3 | open | |
| J6 | `backup` | 3 | open | |
| J7 | `server-upkeep` | 3 | open | |
| J8 | `monitoring` | 3 | open | |
| J9 | `dev-machine` | 3 | open | |
| A1–A4 | `agent-layer` | 3 | open | |
| J10 | `linux-services` | 4 | open | |
