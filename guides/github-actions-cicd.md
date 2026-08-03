# GitHub Actions CI/CD

Reusable workflow patterns for full-stack projects (Go/Java backend + Node frontend, deploy via
AWS OIDC).

The full, copy-paste-ready workflow lives in [templates/ci.yml](../templates/ci.yml); the release
targets live in [templates/Makefile](../templates/Makefile). This guide explains the patterns
behind them.

## Prerequisites

- A repository with `backend/`, `frontend/`, and (optionally) `database/` subdirectories.
- For OIDC deploys: an AWS account where you can create an IAM OIDC provider and role.
- Tooling matching the versions in `templates/ci.yml`: Go 1.26, Node 24, pnpm 10, Java 21.

## AWS OIDC Deploy

Deploys use short-lived credentials via GitHub's OIDC provider — no long-lived secrets stored in
the repo. The deploy job needs `permissions: { id-token: write, contents: read }`.

One-time AWS setup:

1. Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`.
2. Create an IAM role whose trust policy trusts that provider (scope it to your repo/branch).
3. Store the role ARN as `AWS_ROLE_ARN` in the GitHub repo secrets.

The deploy job then assumes the role with `aws-actions/configure-aws-credentials@v6` and runs
`cdk deploy`. Gate it on `needs: [backend-ci, frontend-ci]` so it only runs when CI passes.

## Workflow Hardening

Two zero-maintenance top-level keys in every workflow (see [templates/ci.yml](../templates/ci.yml)):

- `permissions: contents: read` — least-privilege `GITHUB_TOKEN`; a job that needs more
  (e.g. the OIDC deploy) requests its scopes at job level.
- `concurrency` with `cancel-in-progress: true` — rapid pushes cancel superseded runs.

## Dependency Updates

[templates/dependabot.yml](../templates/dependabot.yml) — monthly Dependabot updates, one grouped
PR per ecosystem (github-actions, gomod, npm, docker).

- `github-actions` updater keeps action refs current.
- `go mod tidy -diff` (backend) enforces lockfile-manifest sync in CI.
- `pnpm install --frozen-lockfile` (frontend) enforces lockfile-manifest sync in CI.

## Path Filtering

Skip jobs when unrelated files change. A `changes` job runs `dorny/paths-filter@v4` to detect
which subdirectories were touched, then each downstream job gates on the matching output:

```yaml
backend-ci:
  needs: changes
  if: ${{ needs.changes.outputs.backend == 'true' }}
```

A frontend-only commit no longer triggers backend tests, keeping CI fast. Wire `id: changes` on the
filter step and reference `steps.changes.outputs.<name>` in the job outputs.

## Caching

| Tool | Cache Config |
| ---- | ----------- |
| Go | `cache: true` is default in `actions/setup-go` |
| Maven | `cache: maven` in `actions/setup-java` |
| pnpm | `cache: pnpm` + `cache-dependency-path` in `actions/setup-node` |
| npm | `cache: npm` in `actions/setup-node` |

## Tag-Based Production Deploy

Trigger production deploys by pushing a `prod-*` tag (`on: push: tags: ["prod-*"]`), reusing the
dev deploy steps with `-c stage=prod`. Release from the command line with the `prod-release`
Makefile target — see [templates/Makefile](../templates/Makefile).

## Verify

```bash
# validate workflow syntax locally before pushing
actionlint .github/workflows/ci.yml

# after pushing, confirm the run
gh run list --limit 1
gh run watch
```

Expected: the `changes` job runs first, only the affected `*-ci` jobs execute, and `deploy` runs
last (and only on `main` / a `prod-*` tag).

## Troubleshooting

```bash
# "Resource not accessible by integration" on OIDC deploy
# → Check the permissions: block in the workflow (id-token: write, contents: read)

# Cache not restoring
# → Verify cache-dependency-path matches your lockfile location
# → Check actions/setup-node or actions/setup-go version (cache support varies)

# Tests pass locally but fail in CI
# → Check Go version mismatch: `go version` locally vs `go-version:` in workflow
# → Check for hardcoded paths or env vars that differ in CI

# Path filter not working (all jobs run on every push)
# → Ensure dorny/paths-filter step has `id: changes` and outputs are referenced correctly
```

---

See also:
- [templates/ci.yml](../templates/ci.yml) — full CI workflow template
- [templates/dependabot.yml](../templates/dependabot.yml) — grouped monthly dependency updates
- [templates/Makefile](../templates/Makefile) — Makefile with release targets
- [guides/docker-multi-stage-builds.md](docker-multi-stage-builds.md) — production Docker images
- [guides/go.md](go.md) — Go build-tag separation and integration test setup
