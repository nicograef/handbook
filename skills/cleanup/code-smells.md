# Code Smells

Catalog of structural anti-patterns and AI-generated slop patterns. For each
smell: what it looks like, why it hurts, what to suggest.

---

## Structural Smells

### God Class / God Function

A single class or function that does too many things. Typically 200+ lines,
multiple unrelated responsibilities, hard to name precisely.

**Flag when:**

- A function cannot be summarised in one sentence
- A class has fields that are only used by a subset of its methods
- A file requires scrolling to understand what it does
- A function takes 5+ parameters because it handles multiple concerns

**Suggest:** Identify the separate responsibilities. For cleanup, note them —
do not extract unless the change is small and self-contained. Flag the
improve-architecture skill for large cases.

### Feature Envy

A function that mostly accesses data from another object rather than its own.

**Flag when:**

- A method reads 3+ fields from another object but none from its own
- A helper function exists only to manipulate another class's data
- Logic about an entity lives in a different module than the entity itself

**Suggest:** The logic probably belongs in the other object. Move it there if
the change is small. For cross-module moves, flag for later.

### Shotgun Surgery

One conceptual change requires edits in many unrelated files.

**Flag when:**

- Adding a field to a domain object requires changes in handler, service,
  repository, DTO, test fixture, and migration
- A rename propagates through 5+ files
- Related logic is scattered across layers with no cohesive module

**Suggest:** Note the coupling. This is usually an architectural issue — flag
the improve-architecture skill.

### Primitive Obsession / Stringly Typed

Behavior is controlled by raw strings, ints, or bools instead of domain types.

**Flag when:**

- `if role == "admin"` instead of an enum or type
- A function accepts `(string, string, string, int)` instead of a typed struct
- Currency is stored as `float` instead of a `Money` value object
- Status transitions are managed by comparing string literals

**Suggest:** Introduce a domain type (enum, value object, typed struct) for the
concept. The compiler then enforces correctness instead of convention.

### Boolean Blindness

Functions that accept or return raw booleans, making call sites unreadable.

**Flag when:**

- `process(true, false, true)` — impossible to understand without reading the
  signature
- A boolean parameter toggles between entirely different behaviors
- A returned boolean carries semantic meaning that a named type would clarify

**Suggest:** Use enums, option types, named constants, or separate functions
for distinct behaviors. At minimum, add name clarity at the call site.

### Deep Nesting

4+ levels of indentation from nested if/for/try blocks.

**Flag when:**

- A function has 4+ levels of nesting
- An else branch contains complex logic that could be an early return
- Nested callbacks or promise chains create a "pyramid of doom"

**Suggest:** Invert conditions and use early returns. Extract inner blocks only
if they represent a genuinely separate concern — do not fragment into shallow
helpers.

### Dead Code

Commented-out blocks, unused functions, unreachable branches, stale imports.

**Flag when:**

- Commented-out code with no explanation of why it is kept
- Functions or exports that nothing references
- if/else branches that can never be reached given the type constraints
- Imports that are not used

**Suggest:** Delete it. Version control preserves history. If the code is kept
intentionally, it needs a comment explaining when it will be needed.

### Leaky Abstraction

Callers need to know implementation details to use an API correctly.

**Flag when:**

- A function's documentation warns about internal behavior the caller must
  account for
- Callers routinely pass specific values to work around internal limitations
- Error messages expose internal structure (database column names, internal
  service names)
- A "wrapper" requires the caller to understand what it wraps

**Suggest:** Fix the abstraction so callers do not need internal knowledge. If
the fix is large, flag for later.

### Premature Abstraction / Cargo Culting

Applying patterns because "best practice" without a concrete problem to solve.

**Flag when:**

- A strategy pattern exists for 2 cases
- An event system is wired up for a single synchronous call
- A factory creates one type with no configuration
- An interface exists only because "you should always program to interfaces"
- A DI container is used where constructor arguments would suffice

**Suggest:** Inline the abstraction. Add it back when a second or third use
case makes the pattern earn its keep (Rule of Three).

---

## AI Slop — Code

Patterns commonly introduced by AI-generated code. These overlap with
structural smells but have distinct tells.

### Unnecessary Comments

Comments that restate what the code already says.

**Flag when:**

- `// increment counter` above `counter++`
- `// loop through items` above a for-each
- `// return the result` above a return statement
- Section headers that do not match the file's existing comment style
- Promotional tone: `// elegant solution for...`

**Keep when:**

- The comment explains a non-obvious *why* (business rule, workaround, edge
  case)
- The comment matches the existing documentation density of the file

### Defensive Overkill

Safety nets around code that cannot fail in context.

**Flag when:**

- A nil/null check guards a value that was just constructed or validated one
  line above
- A try/catch wraps code that cannot throw in the current context
- Error handling duplicates what an outer layer already catches
- A guard clause checks for an impossible state given the type system

**Keep when:**

- The check is at a system boundary (HTTP handler, CLI input, external API)
- The surrounding code has the same defensive style — it is the project norm

### Type Escape Hatches

Workarounds that bypass the type system instead of fixing the underlying issue.

**Flag:**

- `as any` / `<any>` casts in TypeScript
- `interface{}` where a concrete type exists in Go
- `// @ts-ignore` or `// @ts-expect-error` without an explanation
- `# type: ignore` in Python without a specific error code
- `@SuppressWarnings` in Java without justification
- Force unwraps or `!` assertions that bypass null safety

**Suggest:** Fix the underlying type issue. Use the correct type or a proper
type assertion with a documented reason.

### Redundant Abstractions

Indirection that adds no value.

**Flag when:**

- A function's entire body is a single forwarded call to another function
- An interface has exactly one implementation and no test double
- A factory does nothing beyond calling a constructor
- A helper exists for a one-time operation
- A utility module wraps standard library functions without adding value

**Suggest:** Inline the wrapper. Remove the single-implementation interface.
Delete the factory. Call the standard library directly.

### Style Drift

Patterns imported from another language or codebase that clash with the
project's conventions.

**Flag when:**

- Naming conventions do not match (camelCase in a snake_case project)
- Import organization differs from the rest of the file
- Error handling patterns are from another language (Go-style `if err != nil`
  rewritten as try/catch in TypeScript)
- Logging patterns do not use the project's logger
- String formatting style differs from the file (template literals vs
  concatenation)
- Brace style or indentation is inconsistent

**Suggest:** Match the file's existing conventions.

### Over-Engineered Error Messages

Error messages written like documentation — multi-sentence, with suggestions
for how to fix the problem.

**Suggest:** Match the project's existing error message style. Usually a short,
specific description suffices.

### Verbose Variable Names

Names longer than the scope warrants.

**Flag when:**

- `filteredAndSortedUserListForDisplay` where `sortedUsers` would suffice
- `isCurrentlyBeingProcessed` where `processing` is clear in context
- A lambda parameter has a 30-character name

**Keep** descriptive names in wide scopes where clarity genuinely matters.

---

## AI Slop — Config and Infrastructure

Patterns in YAML, JSON, Dockerfiles, CI pipelines, and IaC files.

### Narrating Comments

Comments that restate the key name or explain well-known directives.

**Flag when:**

- `# Set the port number` above `port: 8080`
- `# The name of the service` above `name: api`
- `# Expose port 443` above `EXPOSE 443`
- `# Configure the database connection` above a `database:` block

**Keep when:**

- The comment explains *why* a non-obvious value was chosen
- The comment warns about a gotcha or ordering dependency
- The comment documents a workaround for a known issue

### Defensive Defaults

Extra fallbacks and retry logic copied from templates without matching the
actual deployment context.

**Flag when:**

- Health check intervals are generic, not tuned to the service's startup
- `restart: always` on one-shot tasks
- Multiple nested fallback env vars when one level suffices
- Catch-all error handlers in CI that swallow useful output

### Over-Structured Config

Deeply nested hierarchies where a flat structure is idiomatic.

**Flag when:**

- A single value is wrapped in multiple layers of nesting
- Arrays of one item are used where a scalar works
- Anchors and aliases refer to blocks that appear only once

### Template Pollution

Boilerplate from templates that does not apply to the project.

**Flag when:**

- CI steps reference languages or tools not in the project
- Dockerfile stages are never used in the build target
- Commented-out blocks for "optional" features have no explanation of when
  they would be enabled
- Security scanning steps reference tools that are not installed

### Redundant Explicit Defaults

Values that match the tool's documented default, adding noise without
information.

**Flag when:**

- The value is the documented default for the tool
- The setting adds no clarity for the reader
- The project does not have a convention of being explicit about defaults

**Keep when:**

- The default is surprising or has changed between versions
- The project intentionally documents all settings for auditability
