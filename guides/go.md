# Go Backend Guide

Stack-convention guide for Go backend projects — heading-grouped rules, not a runbook.

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

## Linting

Minimum required tooling: `goimports` (formatting) + `golangci-lint` (linting).

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
