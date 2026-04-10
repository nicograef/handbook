# Principles

Checklist of design principles to apply during the review pass. For each
principle: one question to ask, what violations look like, what to suggest.

---

## KISS — Keep It Simple

**Ask:** Is there a simpler way to express this that a team member would
understand on first read?

**Flag when:**

- A chain of map/filter/reduce is less readable than a loop
- A generic abstraction exists for a single concrete use case
- Conditional logic uses nested ternaries or double negation
- A design pattern is applied where a plain function would suffice
- Promise chains are used where async/await would be clearer
- Bitwise tricks or operator overloading replaces readable logic

**Suggest:** Replace with the straightforward version. Optimise for the reader,
not the writer.

---

## YAGNI — You Aren't Gonna Need It

**Ask:** Is this abstraction, extension point, or feature actually used right
now? Or is it speculative?

**Flag when:**

- An interface exists with exactly one implementation and no test double
- A factory function does nothing beyond calling a constructor
- Configuration options exist that are never set to non-default values
- A plugin/extension system has zero plugins
- Generic type parameters are used where a concrete type would work
- An event system is wired up but only one listener exists

**Suggest:** Remove the abstraction. Inline the single implementation. Add the
extension point when a second use case actually appears.

---

## DRY — Don't Repeat Yourself

**Ask:** Is this duplication of knowledge (same business rule, same source of
truth), or is it coincidental similarity (two things that happen to look alike
but represent different concepts)?

**Flag when:**

- The same business rule is encoded in two places (validation in handler AND in
  domain object)
- The same magic number or string literal appears in multiple files without a
  named constant
- A config value is hardcoded in code that already has access to the config

**Do NOT flag when:**

- Two functions have similar structure but represent different domain concepts
- Test setup code is repeated across tests for clarity
- Two API endpoints happen to have similar response shapes

**Suggest:** Extract the shared knowledge to a single source of truth. For
coincidental similarity, leave it alone — wrong DRY (coupling unrelated things)
is worse than repetition.

---

## Single Responsibility (SOLID — S)

**Ask:** Does this function, class, or module have exactly one reason to change?

**Flag when:**

- A function parses input AND executes business logic AND formats output
- A class contains HTTP handling, business rules, and database queries
- A module mixes UI rendering with API calls and state management
- A file grows beyond the point where you can summarise its purpose in one
  sentence

**Suggest:** Identify the separate responsibilities and note which could be
extracted. Do not extract during cleanup — flag for later if the change is
large.

---

## Open/Closed (SOLID — O)

**Ask:** Can new behavior be added without modifying existing code?

**Flag when:**

- A switch/case or if/else chain grows every time a new variant is added
- Adding a new feature requires editing a core module that other features depend
  on
- A function has boolean parameters that toggle between entirely different
  behaviors

**Suggest:** Note the violation. For small cases (2–3 branches), this is often
acceptable — do not over-engineer. Flag only when the pattern is actively
causing maintenance pain.

---

## Liskov Substitution (SOLID — L)

**Ask:** Do subtypes behave correctly when used through the parent interface?

**Flag when:**

- A subclass throws "not implemented" for inherited methods
- A subclass changes the semantics of a parent method (e.g. `save()` that
  silently drops data)
- Type narrowing or casting is required after receiving a value through a
  polymorphic interface

**Suggest:** The hierarchy is wrong. Consider composition or a different
interface split.

---

## Interface Segregation (SOLID — I)

**Ask:** Does any caller depend on methods it does not use?

**Flag when:**

- A function accepts a large object but only reads one field from it
- An interface has 10+ methods but most implementations only use 3–4
- A component receives many props but uses only a few
- A mock needs to stub methods that are irrelevant to the test

**Suggest:** Accept only what is needed — a smaller interface, a specific field,
or a focused prop type.

---

## Dependency Inversion (SOLID — D)

**Ask:** Does high-level business logic depend on abstractions or on concrete
infrastructure?

**Flag when:**

- A service function directly imports a database client, HTTP library, or
  external SDK
- A domain model references framework-specific types (ORM decorators, HTTP
  request objects)
- Business logic cannot be tested without starting infrastructure

**Suggest:** Define an interface in the domain layer. Move the concrete
implementation to infrastructure. Inject the dependency.

---

## Separation of Concerns

**Ask:** Is each layer / module responsible for exactly one concern?

**Flag when:**

- A React component contains fetch calls, business logic, and renders UI
- A backend handler validates input, queries the database, applies business
  rules, and formats the response in a single function
- CSS/styling logic is mixed with data transformation
- A database migration contains business logic
- A test file contains production helpers

**Suggest:** Identify which concern is leaking where. For small leaks, note it.
For large ones, flag the improve-architecture skill.

---

## Principle of Least Surprise

**Ask:** Does this behave the way a reader would expect from the name,
signature, and position in the codebase?

**Flag when:**

- A function named `get*` has side effects (writes to DB, sends email)
- A function named `validate*` silently fixes invalid data instead of rejecting
  it
- A constructor performs I/O, network calls, or heavy computation
- A "utility" module contains business logic
- Return types are surprising (a `save` function that returns the previous
  value)

**Suggest:** Rename to match behavior, or move the surprising side effect to an
explicit call site.

---

## Composition over Inheritance

**Ask:** Is inheritance creating tight coupling where composition would be
simpler and more flexible?

**Flag when:**

- An inheritance hierarchy is deeper than 2 levels
- A base class contains logic that only some subclasses need
- Subclasses override parent methods to disable or alter fundamental behavior
- Multiple inheritance or mixins create diamond-dependency confusion

**Suggest:** Prefer injecting behavior through interfaces, function arguments,
or object composition.

---

## Fail Fast

**Ask:** Are errors caught at the system boundary (where invalid data enters),
or scattered defensively through every internal layer?

**Flag when:**

- Every internal function re-validates data that was already validated at the
  entry point
- Nil/null checks appear on values that were just constructed or returned from a
  trusted internal call
- try/catch wraps code that cannot throw in the current context
- Error handling duplicates what an outer layer already catches

**Suggest:** Validate once at the boundary. Trust your types and your own code
inside the system. Remove redundant defensive checks.

---

## Minimize State and Mutability

**Ask:** Can this be a value instead of a variable? Are side effects explicit
and pushed to the edges of the system?

**Flag when:**

- A `let` / `var` is used where `const` / `val` would suffice
- An object is mutated in place when a new value could be returned
- Shared mutable state is accessed across function boundaries without clear
  ownership
- A function modifies its input parameters as a side effect

**Suggest:** Use immutable values where possible. Return new values instead of
mutating. Push state changes to the outermost layer.
