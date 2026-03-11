# Go Backend Guide

Best practices for Go backend projects.

## Project Setup

Use Go modules. Keep `go.mod` and `go.sum` in version control.

```bash
go mod init github.com/you/project
go mod tidy      # add missing, remove unused
go mod verify    # verify checksums
```

Minimum required tooling: `goimports` (formatting) + `golangci-lint` (linting).

## Project Structure

Organise code by domain, not by layer. Avoid flat package layouts.

```
backend/
  domain/        # pure business logic — no external dependencies
    order/
    product/
    user/
  repository/    # database access (implements domain interfaces)
  api/           # HTTP handlers and request/response types
  app/           # application services / use-case orchestration
  config/        # environment and config loading
  main.go
```

Keep the `domain/` packages free of framework or infrastructure imports. Business rules live here and are tested in isolation.

## Formatting

Use `goimports` — it runs `gofmt` and also manages import grouping (stdlib → third-party → local).

```bash
goimports -w .
```

CI check:

```bash
if [ "$(goimports -l . | wc -l)" -gt 0 ]; then exit 1; fi
```

No manual formatting debates. The tool decides.

## Linting

Use `golangci-lint`. Key linters to enable:

| Linter | Purpose |
| --- | --- |
| `errcheck` | No silently ignored errors |
| `staticcheck` | Advanced static analysis |
| `errorlint` | Correct `errors.Is` / `errors.As` usage |
| `gosec` | Security issues |
| `bodyclose` | HTTP response bodies closed |
| `gocritic` | Common bugs and performance issues |

Run locally:

```bash
golangci-lint run
```

See [`.golangci.yml`](https://golangci-lint.run/usage/configuration/) for the full config format. Check format and lint in CI before running tests.

## Error Handling

Always return errors explicitly. Wrap with context using `%w`:

```go
return fmt.Errorf("create order: %w", err)
```

Use `errors.Is` / `errors.As` for error inspection — never compare error strings.

Sentinel errors for known domain errors:

```go
var ErrNotFound = errors.New("not found")
```

## SQL with sqlc

Use `sqlc` to generate type-safe Go code from raw SQL queries. Write SQL, get Go — no ORM magic.

Workflow:

1. Write migrations in `database/migrations/`
2. Write queries in `sqlc/queries/`
3. Run `sqlc generate` to produce type-safe Go code
4. Use the generated types in `repository/`

```bash
sqlc generate
```

Advantages: queries are plain SQL (reviewable, optimisable), generated code is type-safe, no runtime surprises.

Use `golang-migrate` for managing migrations:

```bash
migrate -path ./database/migrations -database "$DATABASE_URL" up
migrate -path ./database/migrations -database "$DATABASE_URL" down -all
```

## Testing

Separate unit and integration tests with build tags. Each file carries one tag:

```go
// domain/order/order_test.go
//go:build unit
```

```go
// repository/order_test.go
//go:build integration
```

```bash
go test -tags=unit -race ./...
go test -tags=integration -race ./...
```

Always run with `-race`. Test only exported functions — internals are implementation details. Name tests `TestFunctionName_Scenario`.

Use the standard `testing` package. `t.Fatalf` for setup failures, `t.Errorf` for assertions. Extract helpers with `t.Helper()` for accurate failure output.

See [guides/github-actions-cicd.md](github-actions-cicd.md) for the full CI setup including Postgres service containers.

## Code Quality

- **Small, focused functions** — if a function needs a comment to explain what it does, consider splitting it.
- **Explicit over implicit** — Go favours verbose but clear code over magic.
- **No global state** — pass dependencies via constructor or function arguments.
- **Interfaces at the consumer** — define interfaces where they are used, not where they are implemented. Keep them small (1–3 methods).
- **Errors are values** — handle every error at the point it occurs; don't ignore with `_`.
- **Avoid premature abstraction** — start concrete, extract interfaces when you need to swap implementations or test.

---

See also: [theory/go-backend.md](../theory/go-backend.md) for Go backend architecture concepts (German).
