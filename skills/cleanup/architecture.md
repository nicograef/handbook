# Architecture

Checklist for reviewing architectural boundaries, dependency direction, and
module design. Each item is a question to ask during review, what to flag, and
what to suggest.

These are focused checks for incremental review — not a full architectural
assessment. For large-scale restructuring, flag the improve-architecture skill.

---

## Dependency Direction

**Ask:** Do dependencies point inward — infrastructure depends on application,
application depends on domain? Or does domain code import infrastructure?

**Flag when:**

- A domain model imports a database client, ORM, or framework type
- A service layer imports HTTP request/response types
- A domain entity has JSON tags, ORM decorators, or serialization annotations
  as its primary definition
- A core business function imports a concrete external SDK

**Suggest:** Move the infrastructure concern out of the domain. Define an
interface in the domain layer, implement it in infrastructure.

---

## Inversion of Control

**Ask:** Are dependencies injected from the outside, or created internally?

**Flag when:**

- A function calls `new DatabaseClient()` or `sql.Open()` inside business logic
- A service constructor creates its own dependencies instead of receiving them
- Infrastructure is initialised inside a domain function
- A function reads environment variables directly instead of receiving
  configuration as a parameter

**Suggest:** Accept the dependency as a parameter or constructor argument.
Create it at the composition root (main, app startup, DI container) and inject
it inward.

---

## Deep vs. Shallow Modules

**Ask:** Is the interface nearly as complex as the implementation? Does the
module hide significant complexity behind a simple surface, or is it just a
pass-through?

**Flag when:**

- A function's entire body is a single call to another function (pure
  delegation)
- A wrapper adds no logic, validation, or error handling — just forwards
- An interface has as many methods as the struct behind it, each with the same
  signature
- A "service" layer exists that only calls the repository without adding
  business logic
- Helper functions are extracted for single-use operations, fragmenting logic
  across files

**Do NOT flag when:**

- A thin adapter exists at a genuine system boundary (HTTP handler → service)
- A repository interface abstracts persistence for testability — even with a
  thin implementation

**Suggest:** Consider inlining the shallow module. A deep module hides
complexity behind a small interface — if there is nothing to hide, the module is
overhead.

For significant restructuring, flag the improve-architecture skill.

---

## Rich vs. Anemic Domain Model

**Ask:** Do domain objects enforce their own invariants and contain behavior?
Or are they getter/setter bags with all logic in services?

**Flag when:**

- An entity is a plain struct/class with only public fields and no methods
- Business rules about an entity live entirely in a separate service
  (`OrderService.cancel()` instead of `Order.cancel()`)
- An entity can be put into an invalid state by setting fields directly
- Status transitions are managed by external code, not by the entity itself

**Do NOT flag when:**

- The application is genuinely CRUD with no complex business rules — an anemic
  model is appropriate for simple data
- The codebase intentionally uses a Transaction Script or Active Record pattern

**Suggest:** Move the business rule into the entity. Have the entity enforce its
own invariants (e.g. `Order.cancel()` checks if cancellation is allowed).

---

## Repository Pattern

**Ask:** Does the repository provide a clean domain-level abstraction over
persistence?

**Flag when:**

- A repository returns database rows, DTOs, or ORM-generated types instead of
  domain objects
- A repository interface is defined in the infrastructure layer instead of the
  domain layer
- A repository exposes query-builder methods or raw SQL to callers
- There is one repository per database table instead of per aggregate root
- Repository methods leak persistence concerns (e.g. `FindByColumnName` instead
  of `FindByEmail`)

**Suggest:** The repository interface belongs in the domain. It should accept
and return domain objects. Name methods in domain language.

---

## Anti-Corruption Layer

**Ask:** Are external system concepts leaking into the domain?

**Flag when:**

- Raw DTOs or response types from an external API are used directly in service
  or domain code
- External field names, enum values, or conventions appear in domain logic
  (e.g. `if stripeEvent.Type == "payment_intent.succeeded"`)
- A third-party SDK's types are used as function parameters in business logic
- Mapping between external and internal types happens inside domain code instead
  of at the boundary

**Suggest:** Create a thin translation layer at the boundary. Map external
types to domain types before they enter the system. Map domain types to external
types on the way out.

---

## Bounded Context Violations

**Ask:** Is one module using the internal types or data of another module that
should be independent?

**Flag when:**

- A module imports internal types (not shared/public API types) from another
  module
- One module directly queries another module's database tables
- Domain concepts from one context appear in another (e.g. billing concepts in
  the user management module)
- A shared "models" package contains types from multiple unrelated domains

**Suggest:** Define explicit contracts (interfaces, DTOs, events) between
contexts. Each context should own its model and expose only what others need.

For large boundary issues, flag the improve-architecture skill.

---

## Separation from Frameworks

**Ask:** Can the business logic be tested without starting a web server,
database, or message broker?

**Flag when:**

- Business rules are embedded inside HTTP handler functions
- Framework-specific types (request, response, context) are passed deep into
  the application
- A domain service imports a web framework, ORM, or queue library
- Test setup for business logic requires booting infrastructure

**Suggest:** Extract business logic into pure functions or services that accept
plain types. Keep framework code at the edges — handlers, middleware, adapters.

---

## Cross-Layer Consistency

**Ask:** Do the layers agree on types, shapes, and validation rules?

**Flag when:**

- Frontend request body shape does not match backend handler's expected struct
- Frontend response parsing expects fields the backend does not send
- Validation rules differ between frontend and backend (e.g. max length 50 in
  UI but 255 in DB)
- Database schema has constraints (NOT NULL, defaults, enums) that the
  application code does not respect
- Status values or enum options differ between layers
- A generated API client is out of date with the actual API

**Suggest:** Align the shapes. Identify which layer is the source of truth and
update the others to match. For generated code, regenerate from the schema.
