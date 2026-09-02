# Test Anti-Patterns

Use this rubric during Step 2 (Audit) to tag each test as **Keep**, **Refactor**, **Delete**,
or **Merge**.

## Decision Tree

```
1. Does the test make at least one meaningful assertion?
   └─ NO  → DELETE (Tests That Never Fail)

2. Does the test assert only on values the test itself created,
   with no non-trivial logic from the system?
   └─ YES → DELETE (Asserting on Setup Values)

3. Does the test access private/unexported methods or fields directly?
   └─ YES → DELETE (replace with a public-API test if the behavior matters)

4. Does the test assert on internal call counts, argument order,
   or mock invocations of code you own?
   └─ YES → DELETE (or REFACTOR if the same behavior can be verified via output)

5. Does the test mock internal collaborators (classes/modules you own)?
   └─ YES → REFACTOR (replace mocks with real, in-memory, or real-test-DB implementations)

6. Does the test verify state by bypassing the public interface
   (raw SQL, file reads, internal object inspection)?
   └─ YES → REFACTOR (verify through the public interface instead)

7. Is the test name phrased as HOW the system works
   ("calls X", "invokes Y", "sets flag Z") rather than WHAT it does?
   └─ YES → likely REFACTOR (rewrite intent + implementation)

8. Does an identical behavior already have 2+ other tests
   with only trivially different inputs?
   └─ YES → MERGE (keep one; fold the others into a table-driven test)

9. Does the test over-specify error messages (exact string match)?
   └─ YES → REFACTOR (assert on type / code instead)

All NO → KEEP
```

## Coverage Loss Protocol

**Trigger**: a Delete tag removes the only test for a behavior.

1. **Note** it explicitly in the Step 3 report, in this shape:
   ```
   **Warning**: Delete "test name" removes the only coverage for [behavior X].
     Suggest: add a proper test via TDD skill after this review.
   ```
2. **Skip** the replacement test — adding it is out of scope for this skill.
3. **Confirm** with the user before deleting.

## Anti-Patterns

| Anti-pattern | Signal | Why it's bad | Fix |
|---|---|---|---|
| 1. Testing Internal Call Counts | `assert.True(t, mock.chargeCalled)`, `expect(gateway.charge).toHaveBeenCalledWith(cart.total)` | The test breaks whenever `charge` is renamed, inlined, or replaced — even if the user still gets charged correctly. It tests HOW, not WHAT. | Assert on the observable outcome — the returned receipt, the updated order status, the emitted event. |
| 2. Mocking Internal Collaborators | `jest.mock("../userService")`, `assert.True(t, repo.saveCalled)` on your own `mockOrderRepository` — mocking a class or module you own and control, not a system boundary | Creates tight coupling to implementation decisions. Moving logic between collaborators breaks tests without changing behavior. | Use a real implementation, an in-memory fake, or a real test DB; mock the driver only when none is available. Mock only at true system boundaries (HTTP clients, email senders). |
| 3. Testing Private Methods Directly | `func Test_calculateLineItems` on an unexported function, `(repo as any)._buildQuery({ name: "Alice" })` | Private methods are implementation details. They can be merged, split, or renamed freely; testing them directly locks the implementation in place. | Delete the test — the behavior it covers is already exercised through the public API. If it isn't, write a public-API-level test instead. |
| 4. Verifying Through External Means | `db.QueryRow("SELECT COUNT(*) FROM users WHERE name = 'Alice'")` after `createUser`, `fs.readFileSync("/tmp/report.json", "utf8")` after `saveReport` — checking side effects outside the public interface (raw SQL, file reads, internal state) | Breaks if the storage mechanism changes — a different DB schema or file format — even though behavior is identical. | Verify through the same interface the caller would use. |
| 5. Redundant Happy-Path Duplicates | `TestAdd_TwoPositiveNumbers` beside `TestAdd_TwoOtherPositiveNumbers`, `"formats name Alice"` beside `"formats name Bob"` — same success path, trivially different inputs | Adding more examples of the exact same behavior adds noise without adding confidence. One table-driven test covers all cases with less overhead. | Merge into a single table-driven / parameterized test, or delete all but one. |
| 6. Asserting on Test-Setup Values | `expect(cart.items[0].id).toBe(1)` right after `cart.add({ id: 1, price: 10 })`, `assert.Equal(t, "order-123", order.ID)` right after `NewOrder("order-123", items)` — the assertion verifies only data the test set up, so the system under test made no meaningful contribution | These tests cannot fail under any realistic failure mode in the business logic. They are structural tests of the language, not behavioral tests of the system. | Delete, or replace with a test that verifies a non-trivial computed outcome (total price, discount applied, validation enforced). |
| 7. Over-specified Error Messages | `require.EqualError(t, err, "payment failed: card declined: insufficient funds on card ending 4242")`, `expect(err.message).toBe("Payment failed: card declined: …")` — asserting on the exact wording of an error string | Error messages are UI concerns. Rephrasing for better UX breaks the test. | Assert on error type, code, or a stable sentinel — not the full message string. |
| 8. Tests That Never Fail | `_ = err` with no assertion at all, `assert.True(t, true)`, `try { await riskyOperation(); } catch (_) {}` swallowing every error | These tests always pass — they protect nothing. | Delete or add a meaningful assertion. If an error is expected, assert `require.Error(t, err)` / `expect(fn).rejects.toThrow(...)`. |
