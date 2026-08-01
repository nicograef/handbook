# Architecture

Focused checks for incremental review of architectural boundaries — not a full
architectural assessment. Significant restructuring and large boundary issues
are flagged as a separate refactor for the user to schedule, never fixed in
place.

## Dependency Direction

**Flag when:** domain code imports a database client, ORM, framework type, HTTP
request/response type, or a concrete external SDK; an entity's primary
definition is its JSON tags, ORM decorators, or serialization annotations.

## Inversion of Control

**Flag when:** business logic constructs its own dependencies (`new
DatabaseClient()`, `sql.Open()`), a constructor creates instead of receives
them, infrastructure is initialised inside a domain function, or a function
reads environment variables directly instead of receiving configuration as a
parameter.

## Deep vs. Shallow Modules

**Flag when:** a "service" layer exists that only calls the repository without
adding business logic. For the pure-delegation wrapper, single-implementation
interface and single-use helper tells, see
[code-smells.md → Redundant Abstractions](code-smells.md#redundant-abstractions).

**Do NOT flag when:**

- A thin adapter exists at a genuine system boundary (HTTP handler → service)
- A repository interface abstracts persistence for testability — even with a
  thin implementation

## Rich vs. Anemic Domain Model

**Flag when:** an entity is a plain struct/class with only public fields and no
methods, business rules about it live entirely in a separate service
(`OrderService.cancel()` instead of `Order.cancel()`), it can be put into an
invalid state by setting fields directly, or status transitions are managed by
external code.

**Do NOT flag when:**

- The application is genuinely CRUD with no complex business rules — an anemic
  model is appropriate for simple data
- The codebase intentionally uses a Transaction Script or Active Record pattern

## Repository Pattern

**Flag when:** a repository returns database rows, DTOs, or ORM-generated types
instead of domain objects; its interface is defined in the infrastructure layer
instead of the domain layer; it exposes query-builder methods or raw SQL to
callers; there is one repository per database table instead of per aggregate
root; or method names leak persistence concerns (`FindByColumnName` instead of
`FindByEmail`).

## Anti-Corruption Layer

**Flag when:** raw DTOs, response types, field names, enum values or SDK types
from an external system reach service or domain code (e.g. `if stripeEvent.Type
== "payment_intent.succeeded"`), or mapping between external and internal types
happens inside domain code instead of at the boundary.

## Bounded Context Violations

**Flag when:** a module imports internal (non-public-API) types from another
module, directly queries another module's database tables, or carries domain
concepts across contexts (billing concepts in the user management module); or a
shared "models" package contains types from multiple unrelated domains.

## Separation from Frameworks

**Flag when:** business rules are embedded inside HTTP handler functions,
framework-specific types (request, response, context) are passed deep into the
application, a domain service imports a web framework / ORM / queue library, or
test setup for business logic requires booting infrastructure.
