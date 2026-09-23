# Stack Conventions

Heading-grouped rules for the five stacks this handbook builds on — not a runbook.

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

Unit tests carry no build tag; only integration test files start with `//go:build integration`.
gopls loads untagged files by default, so a tagged unit test loses editor support
([gopls settings](https://go.dev/gopls/settings#buildflags)).

`go test ./...` runs the unit tests. CI runs `go test -tags=integration ./...` as a separate job
with a database.

Write migrations in `database/migrations/` and sqlc queries in `sqlc/queries/`.

Use the standard `testing` package: `t.Fatalf` for setup failures, `t.Errorf` for assertions.

## Java

Start every project from [start.spring.io](https://start.spring.io):

- **Language:** Java 25
- **Build:** Maven
- **Dependencies:** Spring Web, Spring Data JPA, PostgreSQL Driver, Flyway Migration, Validation
- **Wrapper:** commit `mvnw` so any environment can build without a local Maven install

```
Controller  →  Service  →  Repository  →  Model
   (HTTP)     (business)    (persistence)   (domain)
```

`./mvnw verify` is the single CI gate — format check + lint + all tests.

Formatting and linting: Spotless (google-java-format, AOSP) + Checkstyle.

Manage schema with Flyway. Never modify existing migrations — only add new ones.

| Layer | Tool | What it tests |
| ----- | ---- | ------------- |
| Controller | `@WebMvcTest` + `MockMvcTester`, `@MockitoBean` for the service | HTTP contract: status codes, JSON shape, validation |
| Service | Mockito (`@ExtendWith(MockitoExtension.class)`) | Business logic in isolation |
| Repository | `@DataJpaTest` + Testcontainers `@ServiceConnection` | Queries and mappings against real Postgres |
| Value Object | Plain JUnit | Pure logic, normalization |
| HTTP Client | `MockRestServiceServer` | Outbound calls without a real network |

`@MockitoBean` belongs in slice tests only. A service test builds its mocks with plain Mockito and
starts no Spring context.

`@DataJpaTest` keeps a `@ServiceConnection` container. Boot 4 replaces only a non-test DataSource
([`Replace.NON_TEST`](https://docs.spring.io/spring-boot/api/java/org/springframework/boot/jdbc/test/autoconfigure/AutoConfigureTestDatabase.Replace.html)).

A controller never talks to a repository. A repository never contains business logic.

Always use constructor injection, never `@Autowired` field injection. Constructor injection is what makes unit tests work without Spring.

## Node/TypeScript

Applies to every TypeScript package; React adds its own rules below.

Run Node 26. It executes `.ts` files directly: [type stripping](https://nodejs.org/api/typescript.html)
is stable and on by default.

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

Node never type-checks. `tsc` does, as its own gate step.

Pin TypeScript to `~6.0`. typescript-eslint supports `>=4.8.4 <6.1.0`, so TypeScript 7 breaks the linter
([dependency versions](https://typescript-eslint.io/users/dependency-versions/)).

Lint with ESLint and typescript-eslint's `recommendedTypeChecked`. Rules like `no-floating-promises`
need type information.

Use pnpm and commit `pnpm-lock.yaml`. CI and the image run `pnpm install --frozen-lockfile`, which
fails instead of re-resolving.

Test with Vitest: it runs TypeScript without a build step.

The gate runs in this order: `pnpm install --frozen-lockfile`, format check, `eslint .`, `tsc`,
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

## Python

Start every project with `uv init --package --python <version>`. It writes `pyproject.toml`,
`.python-version` and the `src/<package>/` layout, so no layout is invented by hand.

`requires-python` in `pyproject.toml` and `.python-version` name the same version. CI and the image
then resolve the interpreter from one fact.

Commit `uv.lock`. CI runs `uv sync --locked`, which fails when the lock no longer matches
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
