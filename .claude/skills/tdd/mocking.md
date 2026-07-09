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

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally.

**Go:**

```go
// Easy to mock — accepts interface
func ProcessPayment(order Order, client PaymentClient) (Receipt, error) {
    return client.Charge(order.Total)
}

// Hard to mock — creates dependency internally
func ProcessPayment(order Order) (Receipt, error) {
    client := stripe.NewClient(os.Getenv("STRIPE_KEY"))
    return client.Charge(order.Total)
}
```

**TypeScript:**

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer specific interfaces over generic ones**

Create specific functions/methods for each external operation instead of one
generic function with conditional logic.

**Go:**

```go
// GOOD: Each method is independently mockable
type UserAPI interface {
    GetUser(ctx context.Context, id string) (User, error)
    ListOrders(ctx context.Context, userID string) ([]Order, error)
    CreateOrder(ctx context.Context, data OrderInput) (Order, error)
}

// BAD: Mocking requires conditional logic
type API interface {
    Do(ctx context.Context, method, path string, body any) (any, error)
}
```

**TypeScript:**

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The specific-interface approach means:

- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which operations a test exercises
- Type safety per operation

## Anti-Patterns

**1. Test-only methods on production classes**

Don't add a method to a production class just so a test can call it. If a
method is only ever invoked from tests, it doesn't belong on the class —
put it in test utilities/helpers instead.

**Go:**

```go
// BAD: SetInternalState only exists for tests
func (s *Service) SetInternalState(state State) {
    s.state = state
}

// GOOD: build the state through the test helper, not the production API
func newServiceWithState(t *testing.T, state State) *Service {
    s := NewService()
    // seed via real constructor args, fixtures, or exported test hooks
    return s
}
```

**TypeScript:**

```typescript
// BAD: resetForTests only exists for tests
class Service {
  resetForTests() {
    this.state = initialState;
  }
}

// GOOD: construct a fresh instance per test instead
function createTestService(overrides = {}) {
  return new Service(overrides);
}
```

**2. Incomplete or partial mocks**

Don't hand-roll a mock that implements only some of an interface's methods.
A partial mock hides real integration gaps — code calling an unmocked
method fails or silently no-ops instead of surfacing the missing
integration. Mock at a true system boundary (fully), or use a real object
(in-memory implementation, test DB, fake server) instead of a partial
stand-in.

```go
// BAD: only Charge is implemented; Refund panics/no-ops if ever called
type partialPaymentClient struct{}
func (p *partialPaymentClient) Charge(amount int) error { return nil }
// Refund, GetStatus, etc. missing — compiler/runtime gap hides real coverage

// GOOD: implement the full interface, or use a real in-memory fake
type fakePaymentClient struct{ charges []int }
func (f *fakePaymentClient) Charge(amount int) error { f.charges = append(f.charges, amount); return nil }
func (f *fakePaymentClient) Refund(amount int) error { /* real fake behavior */ return nil }
func (f *fakePaymentClient) GetStatus(id string) (Status, error) { /* real fake behavior */ return Status{}, nil }
```
