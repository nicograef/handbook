# Stack Conventions

Heading-grouped rules for the three stacks this handbook builds on — not a runbook.

## Go

Organise code by domain, not by layer:

```
backend/
  domain/        # pure business logic — no external dependencies
    order/
    product/
    user/
  repository/    # database access (implements domain interfaces)
  api/           # HTTP handlers and request/response types
  app/           # application services / use-case orchestration
  config/        # environment and config loading
  main.go
```

Keep `domain/` packages free of framework or infrastructure imports — business rules live here and
are tested in isolation.

Separate unit and integration tests with one build tag per file (`//go:build unit` /
`//go:build integration`); `templates/ci.yml` runs both `-tags=unit` and `-tags=integration` as
separate jobs.

Write migrations in `database/migrations/` and sqlc queries in `sqlc/queries/`.

Use the standard `testing` package: `t.Fatalf` for setup failures, `t.Errorf` for assertions.

## Java

Start every project from [start.spring.io](https://start.spring.io):

- **Language:** Java 21
- **Build:** Maven
- **Dependencies:** Spring Web, Spring Data JPA, PostgreSQL Driver, Flyway Migration, Validation
- **Wrapper:** commit `mvnw` so any environment can build without a local Maven install

```
Controller  →  Service  →  Repository  →  Model
   (HTTP)     (business)    (persistence)   (domain)
```

`./mvnw verify` is the single CI gate — format check + lint + all tests.

Formatting and linting: Spotless (google-java-format, AOSP) + Checkstyle.

Manage schema with Flyway. Never modify existing migrations — only add new ones.

| Layer | Tool | What it tests |
| ----- | ---- | ------------- |
| Controller | `@WebMvcTest` + `MockMvc` | HTTP contract: status codes, JSON shape, validation |
| Service | Mockito (`@ExtendWith(MockitoExtension.class)`) | Business logic in isolation |
| Value Object | Plain JUnit 5 | Pure logic, normalization |
| HTTP Client | `MockRestServiceServer` | Outbound calls without a real network |

A controller never talks to a repository. A repository never contains business logic.

Always use constructor injection, never `@Autowired` field injection. Constructor injection is what makes unit tests work without Spring.

## React

Organise by feature, not by type:

```
src/
  components/    # shared, reusable UI components
  pages/         # one file per route
  hooks/         # custom hooks (data fetching, local state)
  service/       # API calls and data-access abstractions
  lib/           # utility functions, formatters, helpers
  test/          # shared test utilities and setup
```

Feature-specific components live next to the page that owns them; move to `components/` only when
shared across multiple pages.

Prefer explicit return types on non-trivial functions. Validate data with Zod at API boundaries.

Use **shadcn/ui** for complex interactive components, and the `cn()` helper (`clsx` +
`tailwind-merge`) to conditionally combine Tailwind classes.

Co-locate component-specific helpers, types, and sub-components — only extract when reused.

Hooks orchestrate calls through the service layer; no raw `fetch` in components or hooks.

Use **Vitest** + **@testing-library/react**; test utility setup goes in `src/test/`.
