# Java / Spring Boot Backend

General guide for building Java backends with Spring Boot. Derived from [nicograef/lexiban](https://github.com/nicograef/lexiban).

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

| Layer | Annotation | Responsibility |
| ----- | ---------- | -------------- |
| Controller | `@RestController` | Parse HTTP request, validate input, delegate to service, return response |
| Service | `@Service` | Business logic, orchestration, caching |
| Repository | `@Repository` | Data access (extend `JpaRepository`) |
| Model | — | Domain entities and value objects |

A controller never talks to a repository. A repository never contains business logic.

---

## Dependency Injection

Always use **constructor injection** — no `@Autowired` field injection.

```java
@Service
public class IbanService {

    private final IbanRepository ibanRepository;
    private final IbanValidator ibanValidator;

    public IbanService(IbanRepository ibanRepository, IbanValidator ibanValidator) {
        this.ibanRepository = ibanRepository;
        this.ibanValidator = ibanValidator;
    }
}
```

Constructor injection makes dependencies explicit, works without a Spring context in unit tests, and makes the class easy to instantiate manually (`new IbanService(repo, validator)`).

---

## DTOs and Java Records

Use **Java records** for request/response DTOs. Records are immutable, have built-in `equals`/`hashCode`/`toString`, and require no boilerplate.

```java
// Request DTO
public record IbanRequest(@NotBlank String iban) {}

// Response DTO
public record ValidationResult(boolean valid, String iban, String bankName, String error) {}
```

Keep domain entities (`@Entity`) separate from DTOs. The controller converts between them.

---

## Key Annotations

| Annotation | Layer | Purpose |
| ---------- | ----- | ------- |
| `@SpringBootApplication` | Root | Enables auto-configuration and component scan |
| `@RestController` | Controller | Combines `@Controller` + `@ResponseBody` |
| `@RequestMapping` / `@PostMapping` | Controller | Maps HTTP routes |
| `@Valid` | Controller | Triggers Bean Validation on request body |
| `@Service` | Service | Marks as Spring-managed service bean |
| `@Repository` | Repository | Marks as Spring-managed repository bean |
| `@Entity` | Model | Maps class to database table |
| `@NotBlank`, `@Size`, `@Pattern` | DTO | Bean Validation constraints |
| `@ExceptionHandler` | Controller | Handles exceptions and returns error responses |
| `@Configuration` / `@Bean` | Config | Defines infrastructure beans (RestClient, etc.) |

---

## SQL, ORM and Flyway Migrations

Use **Spring Data JPA** for persistence. Define entities with `@Entity`, extend `JpaRepository`.

```java
@Entity
public class Iban {
    @Id
    private String iban;
    private String bankName;   // nullable — may be absent for unknown banks
    private boolean valid;
}

public interface IbanRepository extends JpaRepository<Iban, String> {}
```

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

## Clean Code and DDD Principles

- **Single Responsibility** — one class, one reason to change. Split large services.
- **Value Objects** — model domain concepts as immutable classes (e.g., `IbanNumber`). Validate on construction, throw on invalid input.
- **Interfaces for dependencies** — depend on `IbanValidator` interface, not a concrete class. Enables swapping implementations and easy mocking.
- **Meaningful names** — `validateOrLookup()` over `process()`, `IbanFormatException` over `Exception`.
- **No magic primitives** — wrap domain concepts in types (`IbanNumber` instead of `String`).
- **Exception hierarchy** — domain exceptions extend `RuntimeException`; let `@ExceptionHandler` translate them to HTTP responses.

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
- [guides/github-actions-cicd.md](github-actions-cicd.md) — Java + Maven CI job
