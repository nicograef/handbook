# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes — prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Anti-Patterns

**1. Test-only methods on production classes**

Don't add a method to a production class just so a test can call it. If a
method is only invoked from tests, it doesn't belong on the class. Put it in
test utilities or helpers instead.

```go
// BAD: SetInternalState only exists for tests
func (s *Service) SetInternalState(state State) {
    s.state = state
}

// GOOD: build the state through the test helper, not the production API
func newServiceWithState(t *testing.T, state State) *Service {
    s := NewService(WithState(state))
    return s
}
```

**2. Incomplete or partial mocks**

Don't hand-roll a mock that implements only some of an interface's methods —
partial mocks hide integration gaps.

- An unmocked method fails or silently no-ops, hiding the real gap.
- Mock the full boundary, or use a real fake (in-memory implementation, test
  DB, fake server) — never a partial stand-in.

```go
// BAD: only Charge is implemented; the struct fails to compile against the interface
type partialPaymentClient struct{}
func (p *partialPaymentClient) Charge(amount int) error { return nil }
// Refund, GetStatus, etc. missing — a nil-method panic needs an embedded interface instead

// GOOD: implement the full interface, or use a real in-memory fake
type fakePaymentClient struct{ charges []int }
func (f *fakePaymentClient) Charge(amount int) error { f.charges = append(f.charges, amount); return nil }
func (f *fakePaymentClient) Refund(amount int) error { /* real fake behavior */ return nil }
func (f *fakePaymentClient) GetStatus(id string) (Status, error) { /* real fake behavior */ return Status{}, nil }
```
