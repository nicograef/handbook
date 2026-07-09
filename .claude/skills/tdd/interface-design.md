# Interface Design for Testability

## Deep modules

A **deep module** hides substantial functionality behind a small, testable
interface that rarely changes — the opposite of a shallow module, whose
interface is nearly as complex as the implementation it wraps. Prefer deep
modules: fewer methods and simpler parameters mean less test setup and fewer
tests, while the hidden complexity stays isolated behind a stable contract. When
designing an interface, ask whether you can reduce the number of methods,
simplify the parameters, or push more complexity inside.

## Testability

Good interfaces make testing natural:

**1. Accept dependencies, don't create them**

**Go:**

```go
// Testable — dependency injected
func ProcessOrder(ctx context.Context, order Order, gw PaymentGateway) error {
    return gw.Charge(ctx, order.Total)
}

// Hard to test — dependency created internally
func ProcessOrder(ctx context.Context, order Order) error {
    gw := stripe.NewGateway(os.Getenv("STRIPE_KEY"))
    return gw.Charge(ctx, order.Total)
}
```

**TypeScript:**

```typescript
// Testable
function processOrder(order, paymentGateway) {}

// Hard to test
function processOrder(order) {
  const gateway = new StripeGateway();
}
```

**2. Return results, don't produce side effects**

**Go:**

```go
// Testable — returns a value
func CalculateDiscount(cart Cart) (Discount, error) { ... }

// Hard to test — mutates input
func ApplyDiscount(cart *Cart) { cart.Total -= discount }
```

**TypeScript:**

```typescript
// Testable
function calculateDiscount(cart): Discount {}

// Hard to test
function applyDiscount(cart): void {
  cart.total -= discount;
}
```

**3. Small surface area**

- Fewer methods = fewer tests needed
- Fewer params = simpler test setup
