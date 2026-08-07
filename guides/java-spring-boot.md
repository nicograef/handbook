# Java / Spring Boot Backend

Stack-convention guide for Java backends with Spring Boot — heading-grouped rules, not a runbook.
Derived from [nicograef/lexiban](https://github.com/nicograef/lexiban).

---

## Setup

Start every project from [start.spring.io](https://start.spring.io). Typical selections:

- **Language:** Java 21
- **Build:** Maven
- **Dependencies:** Spring Web, Spring Data JPA, PostgreSQL Driver, Flyway Migration, Validation
- **Wrapper:** commit `mvnw` so any environment can build without a local Maven install

Run locally:

```bash
./mvnw spring-boot:run
./mvnw verify          # format check + lint + all tests — use as the single CI gate
```

---

## Layered Architecture

Strictly separate concerns into four layers. Dependencies only flow downward.

```
Controller  →  Service  →  Repository  →  Model
   (HTTP)     (business)    (persistence)   (domain)
```

A controller never talks to a repository. A repository never contains business logic.

---

## Dependency Injection

Always use **constructor injection** — no `@Autowired` field injection.

---

## SQL, ORM and Flyway Migrations

Use **Spring Data JPA** for persistence. Define entities with `@Entity`, extend `JpaRepository`.

Manage schema with **Flyway**. Never modify existing migrations — only add new ones.

```
src/main/resources/db/migration/
  V1__initial_schema.sql
  V2__add_bank_code.sql
```

Naming convention: `V{version}__{description}.sql`. Flyway auto-runs on startup.

---

## Formatting and Linting

Use **Spotless** (auto-formatter) and **Checkstyle** (linter), both wired into `./mvnw verify`.

In `pom.xml`:

```xml
<!-- Spotless: google-java-format, AOSP style (4-space indent) -->
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
</plugin>

<!-- Checkstyle: custom rules in checkstyle.xml -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
</plugin>
```

Fix formatting locally:

```bash
./mvnw spotless:apply    # auto-format all Java files
./mvnw verify            # verify format + lint + tests
```

---

## Testing

Each layer has its own tool. Tests run with `./mvnw verify`.

| Layer | Tool | What it tests |
| ----- | ---- | ------------- |
| Controller | `@WebMvcTest` + `MockMvc` | HTTP contract: status codes, JSON shape, validation |
| Service | Mockito (`@ExtendWith(MockitoExtension.class)`) | Business logic in isolation |
| Value Object | Plain JUnit 5 | Pure logic, normalization |
| HTTP Client | `MockRestServiceServer` | Outbound calls without a real network |

Key rules:

- **Test public API only** — never test private methods
- **`@MockitoBean`** in `@WebMvcTest`; **`@Mock` + manual constructor** in plain unit tests
- **Constructor injection** is what makes unit tests work without Spring
- One test class per production class, same package structure in `src/test`

---

See also:
- [guides/docker-multi-stage-builds.md](docker-multi-stage-builds.md) — multi-stage builds for Java
- [guides/github-actions-cicd.md](github-actions-cicd.md) — CI patterns; Maven caching
