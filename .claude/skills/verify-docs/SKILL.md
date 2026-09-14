---
name: verify-docs
description: Fact-checks committed docs against code, read-only command output and official upstream sources, and against itself. Fixes what it can prove wrong, deletes what is false beyond repair, reports the rest. Run in a fresh session after /distill.
argument-hint: "[path ...] [since <ref>] [report-only]"
disable-model-invocation: true
---

# Verify Docs

Decide whether each documented claim is true. Nothing is settled without an artifact produced this session. That is a file excerpt with `path:line`, the stdout of a command run here, or a fetched URL with its date. Training data is not a source; the failure this prevents is confidently correcting a right line.

## Hard rules

- Clean working tree; record the HEAD sha the report cites. Run the repo's own checks first (`make check`, link linter, docs build) and keep the output. A passing link check settles those claims.
- Read-only commands only: `--help`, `--version`, `--dry-run`, `git log|show|ls-files`, `ls`, `stat`, `shellcheck`, `make -n`, validators. Nothing that installs, starts, writes, deletes or reaches a remote host. A claim that can only be settled by running the real thing is UNREACHED.
- The dev machine is not the target host. A local version says nothing about a Debian server or a CI image. Record where output came from; downgrade to UNREACHED for hosts you cannot read.
- A claim about a template is checked against the template, not the repo's own instance of it.
- A pinned older version is a decision, not staleness. Check the lockfile or CI config before treating an upstream release as evidence.
- The distillation's decisions stay closed: no re-arguing kept files, no cutting for wordiness. Only truth is on the table. Generated docs are fixed at the generator.
- Default scope is the whole corpus; `since <ref>` is an opt-in narrowing. A surviving paragraph can be wrong today because its surroundings changed.

## Workflow

1. Baseline: checks, sha, `git ls-files '*.md' '*.mdx' '*.rst'` plus comment-bearing sources in scope, total lines. Read the handoff commit message; a distill run lists FLAGs there. They set priority, not scope. Each is reported by name whatever it resolves to.
2. Extract claims, each as `location`, a falsifiable one-liner, a lane, and the exact file, command or URL that settles it. Claims: commands, flags, paths, targets, versions and pins. Names of services, env vars, functions and config keys. Anchors and external URLs. Behaviour statements ("X does Y", "the default is Z"), ordering and prerequisites. Conventions, rationale and tribal knowledge get lane `none`. Fan out extraction past ~10 files to `sonnet` workers grouped by directory.

   | Lane | Covers | Settled by |
   | --- | --- | --- |
   | repo | Paths, targets, script flags, env vars, config keys, function names, relative links | Reading the definition; a grep hit on a heading proves only that the word appears |
   | command | Installed versions, existing flags, real defaults | Read-only output, with the machine named |
   | upstream | Third-party behaviour, deprecated flags, current versions, security guidance | Vendor docs, project repo or RFC via web-researcher or WebFetch, with URL and date |
   | none | Preferences, rationale, tribal knowledge | Nothing; count them in one line, check only that they do not contradict each other |

   Precedence: about this repo, repo > command > upstream; about a third-party tool, upstream > command > repo; a doc never verifies a doc.

3. Verify on `opus`, one verdict per claim. TRUE; FALSE, recording the correct value if the lane gives one; STALE, recording what superseded it; UNREACHED, recording why. Code broken while the doc is right, or two lanes disagreeing, are repo findings, not doc fixes.
4. Cross-doc pass yourself after all verifiers return: contradictions, drifted duplicates, dead anchors and 404 URLs. Note structural issues only in passing; they belong to distill and cleanup.
5. Triage:

   | Finding | Action |
   | --- | --- |
   | FALSE or STALE with a verified current value | Fix |
   | Dead internal link or anchor, target found | Fix the link |
   | Dead link, no target; dead URL, no replacement | Delete the link, keep the claim if it still verifies |
   | Two docs contradict, one side verified | Fix the losing side, report both |
   | Two docs contradict, neither verified | Report only |
   | FALSE or STALE, correct value unknown | Delete the claim, report it |
   | UNREACHED; doc right and code wrong; lanes disagree | Report only |

   Tripwire: if fixes plus deletions exceed about a tenth of the claims, stop and ask. The likelier cause is a wrong baseline (branch, host, submodule), not a corpus that rotted that far.
6. Fix with the smallest edit that makes the claim true. A correction never lengthens a file or restyles it. Fan out to `sonnet` by file once the triage table names file, line and value.
7. Report and commit. Counts line first (`142 claims — 9 fixed, 3 deleted, 4 unreached`), then every fix as `file:line`, was → now, artifact. Then unresolved contradictions with both locations, UNREACHED claims with reasons, and every inherited FLAG by name. Commit `docs: correct <scope> against verified sources` with the substantive corrections and UNREACHED claims in the body. `report-only` edits and commits nothing.
