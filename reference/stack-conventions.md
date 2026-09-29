# Stack Conventions

Heading-grouped rules for the four stacks this handbook builds on — not a runbook.

## Node/TypeScript

Applies to every TypeScript package; React adds its own rules below.

Run the current Active LTS, and move within a month of a new LTS. Node executes `.ts` files directly:
[type stripping](https://nodejs.org/api/typescript.html) is on by default.

Pin the Node major in `.node-version`. CI reads it through `node-version-file`, and the image's `node:` tag repeats it.

Type stripping erases types and nothing else. Enums, runtime namespaces, parameter properties and
decorators fail at load; `erasableSyntaxOnly` makes `tsc` reject them first:

```json
{
  "compilerOptions": {
    "noEmit": true,
    "target": "esnext",
    "module": "nodenext",
    "rewriteRelativeImportExtensions": true,
    "erasableSyntaxOnly": true,
    "verbatimModuleSyntax": true,
    "strict": true
  }
}
```

Node never type-checks. `tsc -b` does, as its own gate step. Plain `tsc` checks nothing under
Vite's solution-style tsconfig.

Pin TypeScript to `~6.0`. typescript-eslint supports `>=4.8.4 <6.1.0`, so TypeScript 7 breaks the linter
([dependency versions](https://typescript-eslint.io/users/dependency-versions/)).

Lint with ESLint and typescript-eslint's `recommendedTypeChecked`. Rules like `no-floating-promises`
need type information.

Pin pnpm with `packageManager` in `package.json`, an exact `pnpm@<version>`. CI's pnpm setup reads it.

Use pnpm and commit `pnpm-lock.yaml`. CI and the image run `pnpm install --frozen-lockfile`, which
fails instead of re-resolving.

Test with Vitest: it runs TypeScript without a build step.

The gate runs in this order: `pnpm install --frozen-lockfile`, format check, `eslint .`, `tsc -b`,
`vitest run`.

## React

Organise by feature, not by type:

```
src/
  features/
    <name>/      # components, hooks, API calls and tests of one feature
  components/    # shared UI, used by two or more features
  lib/           # shared utilities, API client, formatters
  test/          # shared test setup and utilities
```

Code leaves a feature folder only when a second feature uses it. Until then, helpers, types and
sub-components stay next to their one user.

Prefer explicit return types on non-trivial functions. Validate data with Zod at API boundaries.

Use **shadcn/ui** for complex interactive components, and the `cn()` helper from the `cn`
package to conditionally combine Tailwind classes.

Components call their feature's API functions; no raw `fetch` in components or hooks.

Use **Vitest** + **@testing-library/react**; test utility setup goes in `src/test/`.

Tests fake the single API client and render with a real query client. They never mock the project's
own modules, so a refactor behind the API client breaks no test.

## Python

Start every project with `uv init --package --python <version>`. It writes `pyproject.toml`,
`.python-version` and the `src/<package>/` layout, so no layout is invented by hand.

`.python-version` is the interpreter pin; uv reads it locally and in CI. `requires-python` is the floor.
The `Dockerfile.python` base tag repeats the pin literally.

Pin uv with `[tool.uv] required-version = "==<version>"` in `pyproject.toml`. uv refuses to run at any
other version, CI's setup-uv reads it, and the base tag repeats it.

Commit `uv.lock`. CI runs `uv sync --locked`, which fails when the lock is out of sync with
`pyproject.toml`. The image runs `uv sync --frozen`: it installs the lock as is, unchecked.

Dev tools live in the `dev` dependency group: `pytest`, `ruff`, `ty`. Nothing is installed globally,
so a fresh checkout and CI run the same versions.

Lint and format with ruff, extending its default rule set. Ruff reads the target version from `requires-python`:

```toml
[tool.ruff]
line-length = 100

[tool.ruff.lint]
# extend-select adds to the default set; a bump that adds rules surfaces as a finding, not a silent pass.
extend-select = ["I", "B", "UP", "N"]
```

Type-check with ty, not mypy. Keep `[tool.ty.src] exclude = []`: an excluded module is checked by nothing.

Configure pytest in `pyproject.toml` with the native `[tool.pytest]` table (pytest 9):

```toml
[tool.pytest]
testpaths = ["tests"]
strict = true
markers = ["<marker>: needs a real backend or a paid provider"]
addopts = ["-m", "not <marker>"]
```

`strict = true` turns unregistered markers and unknown config keys into errors. `uv.lock` pins pytest,
so new strictness options arrive only with a bump.

An opt-in marker names a real backend or a paid provider. `addopts` deselects it, so the gate stays
offline by default.

The gate runs in this order: `uv sync --locked`, `ruff check .`, `ruff format --check .`, `ty check .`,
`pytest`, `uv audit`. `uv audit` runs last because it depends on an outside vulnerability service.

`uv audit` is a preview feature and prints an experimental warning; its output may change.

## Go

Organise code by domain, not by layer:

```
backend/
  cmd/
    <name>/
      main.go      # wiring only: config, stores, services, handlers, server
  internal/
    config/        # environment and config loading
    <domain>/      # one package per domain, e.g. order/
      handler.go   # HTTP handlers and request/response types
      service.go   # business rules
      store.go     # database access
```

Each domain package owns its handler, service and store. `internal/` keeps them unimportable from
other modules.

`service.go` depends on a store interface it declares, so business rules are tested without a database.

Test by layer. Service logic runs against the store interface and a stateful in-memory fake.
Repository code and SQL run against a real database only; a fake cannot catch a wrong query.

Unit tests carry no build tag; only integration test files start with `//go:build integration`.
gopls loads untagged files by default, so a tagged unit test loses editor support
([gopls settings](https://go.dev/gopls/settings#buildflags)).

`go test ./...` runs the unit tests. CI runs `go test -tags=integration ./...` as a separate job
with a database.

Write migrations in `database/migrations/` and sqlc queries in `sqlc/queries/`.

Use the standard `testing` package: `t.Fatalf` for setup failures, `t.Errorf` for assertions.

Lint with golangci-lint v2 from [templates/golangci.yml](../templates/golangci.yml). Its forbidigo rule
shows how to guard a layer boundary.

CI and hooks format with goimports. The editor keeps the gopls defaults and organizes imports on save,
so both agree without gofumpt.

The `go` directive in `go.mod` is the pin. CI reads it through `go-version-file`; the `Dockerfile.go` base tag
repeats its minor.
