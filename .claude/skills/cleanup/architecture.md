# Architecture

- Significant restructuring and large boundary issues are flagged as a separate
  refactor for the user to schedule. Never fix those in place.

## Dependency Direction

**Flag when:**

- An entity's primary definition is its JSON tags, ORM decorators, or serialization annotations.

## Inversion of Control

**Flag when:**

- Infrastructure is initialised inside a domain function.
- A function reads environment variables directly instead of receiving configuration as a parameter.

## Deep vs. Shallow Modules

**Flag when:**

- A "service" layer only calls the repository without adding business logic.
- Pure-delegation wrapper, single-implementation interface and single-use helper tells: [code-smells.md → Redundant Abstractions](code-smells.md#redundant-abstractions).

**Do NOT flag when:**

- A thin adapter exists at a genuine system boundary (HTTP handler → service)
- A repository interface abstracts persistence for testability — even with a
  thin implementation

## Rich vs. Anemic Domain Model

**Flag when:**

- The entity can be put into an invalid state by setting fields directly.
- Status transitions are managed by external code.

**Do NOT flag when:**

- The application is genuinely CRUD with no complex business rules — an anemic
  model is appropriate for simple data
- The codebase intentionally uses a Transaction Script or Active Record pattern

## Repository Pattern

**Flag when:**

- A repository returns database rows, DTOs, or ORM-generated types instead of domain objects.
- Its interface is defined in the infrastructure layer instead of the domain layer.
- It exposes query-builder methods or raw SQL to callers.
- There is one repository per database table instead of per aggregate root.
- Method names leak persistence concerns (`FindByColumnName` instead of `FindByEmail`).

## Anti-Corruption Layer

**Flag when:**

- Raw DTOs, response types or field names from an external system reach service or domain code.
- Enum values or SDK types from an external system reach service or domain code (e.g. `if stripeEvent.Type == "payment_intent.succeeded"`).
- Mapping between external and internal types happens inside domain code instead of at the boundary.

## Bounded Context Violations

**Flag when:**

- A module imports internal (non-public-API) types from another module.
- A module directly queries another module's database tables.
- A module carries domain concepts across contexts (billing concepts in the user management module).
- A shared "models" package contains types from multiple unrelated domains.

## Separation from Frameworks

**Flag when:**

- Test setup for business logic requires booting infrastructure.
