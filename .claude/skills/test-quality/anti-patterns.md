# Test Anti-Patterns

| Anti-pattern | Signal | Why it's bad | Fix |
|---|---|---|---|
| 1. Testing Internal Call Counts | `assert.True(t, mock.chargeCalled)`, `expect(gateway.charge).toHaveBeenCalledWith(cart.total)` | The test breaks whenever `charge` is renamed, inlined, or replaced — even if the user still gets charged correctly. It tests HOW, not WHAT. | Assert on the observable outcome — the returned receipt, the updated order status, the emitted event. |
| 2. Mocking Internal Collaborators | `jest.mock("../userService")`, `assert.True(t, repo.saveCalled)` on your own `mockOrderRepository` — mocking a class or module you own and control, not a system boundary | Creates tight coupling to implementation decisions. Moving logic between collaborators breaks tests without changing behavior. | Use a real implementation or an in-memory fake. Mock only at system boundaries (HTTP clients, email senders, the database driver itself). |
| 3. Testing Private Methods Directly | `func Test_calculateLineItems` on an unexported function, `(repo as any)._buildQuery({ name: "Alice" })` | Private methods are implementation details. They can be merged, split, or renamed freely; testing them directly locks the implementation in place. | Delete the test — the behavior it covers is already exercised through the public API. If it isn't, write a public-API-level test instead. |
| 5. Redundant Happy-Path Duplicates | `TestAdd_TwoPositiveNumbers` beside `TestAdd_TwoOtherPositiveNumbers`, `"formats name Alice"` beside `"formats name Bob"` — same success path, trivially different inputs | Adding more examples of the exact same behavior adds noise without adding confidence. One table-driven test covers all cases with less overhead. | Merge into a single table-driven / parameterized test, or delete all but one. |
| 6. Asserting on Test-Setup Values | `expect(cart.items[0].id).toBe(1)` right after `cart.add({ id: 1, price: 10 })`, `assert.Equal(t, "order-123", order.ID)` right after `NewOrder("order-123", items)` — the assertion verifies only data the test set up, so the system under test made no meaningful contribution | These tests cannot fail under any realistic failure mode in the business logic. They are structural tests of the language, not behavioral tests of the system. | Delete, or replace with a test that verifies a non-trivial computed outcome (total price, discount applied, validation enforced). |
| 8. Tests That Never Fail | `_ = err` with no assertion at all, `assert.True(t, true)`, `try { await riskyOperation(); } catch (_) {}` swallowing every error | These tests always pass — they protect nothing. | Delete or add a meaningful assertion. If an error is expected, assert `require.Error(t, err)` / `expect(fn).rejects.toThrow(...)`. |

## 4. Verifying Through External Means

- **Signal**: `db.QueryRow("SELECT COUNT(*) FROM users WHERE name = 'Alice'")` after `createUser`.
- **Signal**: `fs.readFileSync("/tmp/report.json", "utf8")` after `saveReport`.
- **Pattern**: after calling the public interface, side effects are checked outside it.
- **Outside** covers raw SQL queries, reading files directly, and inspecting internal state.
- **Why it's bad**: breaks if the storage mechanism changes, even though behavior is identical.
- **Storage change** covers a different DB schema or a different file format.
- **Fix**: verify through the same interface the caller would use.

```go
// GOOD
func TestCreateUser_IsRetrievable(t *testing.T) {
    user, err := createUser(ctx, store, User{Name: "Alice"})
    require.NoError(t, err)
    retrieved, err := getUser(ctx, store, user.ID)
    require.NoError(t, err)
    assert.Equal(t, "Alice", retrieved.Name)
}
```

## 7. Over-specified Error Messages

- **Signal**: `require.EqualError(t, err, "payment failed: card declined: insufficient funds on card ending 4242")`.
- **Signal**: `expect(err.message).toBe("Payment failed: card declined: …")`.
- **Pattern**: asserting on the exact wording of an error string.
- **Why it's bad**: error messages are UI concerns. Rephrasing for better UX breaks the test.
- **Fix**: assert on error type, code, or a stable sentinel — not the full message string.

```go
// GOOD
var paymentErr *PaymentError
require.ErrorAs(t, err, &paymentErr)
assert.Equal(t, "card_declined", paymentErr.Code)
```
