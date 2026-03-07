# Go Testing

Best practices for Go unit and integration tests.

## Build Tag Separation

Use `//go:build` tags to keep unit and integration tests completely separate.
Unit tests run fast with no external services; integration tests need a real database.

```go
//go:build unit

package table
```

```go
//go:build integration

package repository
```

```bash
# Unit tests only (fast, no external services)
go test -tags=unit -race ./...

# Integration tests only (requires running DB + migrations)
go test -tags=integration -race ./...
```

## Test Only Public Functions

Only test exported functions. Internal helpers are implementation details — they can
change freely without breaking tests.

```go
// ✅ Test the exported function
func TestGetBalanceFromEvents_OrderOnly(t *testing.T) {
    products := []LineItem{{ID: 1, PriceCents: 500, Quantity: 2}}
    events := []Event{mustCreateOrderEvent(t, products)}

    balance, err := GetBalanceFromEvents(events)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if balance != 1000 {
        t.Fatalf("expected 1000, got %d", balance)
    }
}

// ❌ Do not test unexported helpers directly
func TestAccumulateVariants(t *testing.T) { ... } // avoid
```

## Naming Convention

`TestFunctionName_Scenario` — one function per scenario, no `t.Run` unless many
parameterised inputs make it worthwhile.

```go
func TestGetBalanceFromEvents_Empty(t *testing.T)           {}
func TestGetBalanceFromEvents_OrderOnly(t *testing.T)       {}
func TestGetBalanceFromEvents_OrderAndPayment(t *testing.T) {}
func TestGetBalanceFromEvents_WithSnapshot(t *testing.T)    {}
```

## Race Detection

Always pass `-race`. Catches data races during development and in CI.

```bash
go test -tags=unit -race ./...
```

## Test Helpers with t.Helper()

Extract repetitive setup into helpers. Call `t.Helper()` so failure output points to
the call site, not the helper body.

```go
func mustCreateEvent(t *testing.T, products []LineItem) Event {
    t.Helper()
    event, err := NewOrderPlacedEvent(products)
    if err != nil {
        t.Fatalf("failed to create event: %v", err)
    }
    return event
}
```

## Assertions Without a Library

Standard `testing` is sufficient for most cases — no testify required.

```go
if got != want {
    t.Fatalf("expected %d, got %d", want, got)
}
if len(items) != 2 {
    t.Fatalf("expected 2 items, got %d", len(items))
}
```

Use `t.Fatalf` (stops the test immediately) for setup failures, `t.Errorf` (continues)
for assertion failures when you want all errors reported in one run.

## Integration Tests in CI

Spin up a PostgreSQL service container, apply migrations, run integration tests, then
roll back:

```yaml
integration-tests:
  services:
    postgres:
      image: postgres:17
      env:
        POSTGRES_USER: admin
        POSTGRES_PASSWORD: admin
        POSTGRES_DB: mydb
      ports:
        - 5432:5432
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
  steps:
    - uses: actions/checkout@v5
    - uses: actions/setup-go@v6
      with:
        go-version: 1.24.0
    - run: go mod download

    - name: Install golang-migrate
      run: |
        curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.19.1/migrate.linux-amd64.tar.gz" \
          | tar -xz -C /usr/local/bin

    - name: Run migrations up
      run: migrate -path ./database/migrations -database "postgres://admin:admin@localhost:5432/mydb?sslmode=disable" up

    - name: Run integration tests
      env:
        POSTGRES_HOST: localhost
        POSTGRES_PORT: "5432"
        POSTGRES_USER: admin
        POSTGRES_PASSWORD: admin
        POSTGRES_DBNAME: mydb
        JWT_SECRET: test-secret
      run: go test -tags=integration -v -race ./...

    - name: Run migrations down
      if: always()
      run: migrate -path ./database/migrations -database "postgres://admin:admin@localhost:5432/mydb?sslmode=disable" down -all
```

## Coverage

Generate and print coverage as part of the unit test run:

```bash
go test -tags=unit -race -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```
