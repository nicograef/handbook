# Code Smells

- [Structural Smells](#structural-smells)
- [AI Slop — Code](#ai-slop--code)
- [AI Slop — Config and Infrastructure](#ai-slop--config-and-infrastructure)

## Structural Smells

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

## AI Slop — Code

Patterns commonly introduced by AI-generated code. These overlap with
structural smells but have distinct tells.

### Unnecessary Comments

Comments that restate what the code already says. **Flag when:**

- `// increment counter` above `counter++`, `// loop through items` above a
  for-each, `// return the result` above a return statement
- Section headers that do not match the file's existing comment style
- Promotional tone: `// elegant solution for...`

**Keep when:**

- The comment explains a non-obvious *why* (business rule, workaround, edge
  case)
- The comment matches the existing documentation density of the file

### Defensive Overkill

Safety nets around code that cannot fail in context. **Flag when:**

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

- `as any` / `<any>` casts in TypeScript; `interface{}` where a concrete type
  exists in Go; generic `Object` types where a specific type is available
- `// @ts-ignore` or `// @ts-expect-error` without an explanation
- `# type: ignore` in Python without a specific error code
- `@SuppressWarnings` in Java without justification
- Force unwraps or `!` assertions that bypass null safety

**Suggest:** Fix the underlying type issue. Use the correct type or a proper
type assertion with a documented reason.

### Redundant Abstractions

Indirection that adds no value. **Flag when:**

- A function's entire body is a single forwarded call to another function
- An interface has exactly one implementation and no test double
- A factory does nothing beyond calling a constructor
- A helper exists for a one-time operation
- A utility module wraps standard library functions without adding value

**Suggest:** Inline the wrapper. Remove the single-implementation interface.
Delete the factory. Call the standard library directly. Add the abstraction
back when a second or third use case makes it earn its keep (Rule of Three).

### Over-Engineered Error Messages

Error messages written like documentation. **Flag when:**

- The message runs to multiple sentences
- The message suggests how to fix the problem

**Suggest:** Match the project's existing error message style. Usually a short,
specific description suffices.

### Verbose Variable Names

Names longer than the scope warrants. **Flag when:**

- `filteredAndSortedUserListForDisplay` where `sortedUsers` would suffice
- `isCurrentlyBeingProcessed` where `processing` is clear in context
- A lambda parameter has a 30-character name

**Keep** descriptive names in wide scopes where clarity genuinely matters.

### Unnecessary Complexity

Over-engineered control flow where a simpler form reads better. Overlaps with
[Deep Nesting](readability.md#deep-nesting) and
[Redundant Abstractions](#redundant-abstractions) — the distinct tells:

- Boolean logic uses double negation or unnecessary ternaries (`x ? true : false`)
- Promise chains are used where `async`/`await` would read more clearly
- A `map`/`filter`/`reduce` chain is harder to follow than a simple loop

**Suggest:** Rewrite in the simplest form that expresses the intent.

## AI Slop — Config and Infrastructure

Patterns in YAML, JSON, Dockerfiles, CI pipelines, and IaC files.

### Narrating Comments

Comments that restate the key name or explain well-known directives.
**Flag when:**

- `# Set the port number` above `port: 8080`, `# The name of the service` above
  `name: api`, `# Expose port 443` above `EXPOSE 443`
- `# Configure the database connection` above a `database:` block

**Keep when:**

- The comment explains *why* a non-obvious value was chosen
- The comment warns about a gotcha or ordering dependency
- The comment documents a workaround for a known issue
- The comment notes an environment-specific override

### Defensive Defaults

Extra fallbacks and retry logic copied from templates without matching the
actual deployment context. **Flag when:**

- Health check intervals are generic, not tuned to the service's startup
- `restart: always` on one-shot tasks
- Multiple nested fallback env vars when one level suffices
- Catch-all error handlers in CI that swallow useful output

### Over-Structured Config

Deeply nested hierarchies where a flat structure is idiomatic. **Flag when:**

- A single value is wrapped in multiple layers of nesting
- Arrays of one item are used where a scalar works
- Anchors and aliases refer to blocks that appear only once
- Separate files hold configs that belong together

### Template Pollution

Boilerplate from templates that does not apply to the project. **Flag when:**

- CI steps reference languages or tools not in the project
- Dockerfile stages are never used in the build target
- Commented-out blocks for "optional" features have no explanation of when
  they would be enabled
- Security scanning steps reference tools that are not installed

**Keep** commented-out sections that follow the project's template conventions
(this handbook's templates use commented-out optional sections by design).

### Redundant Explicit Defaults

Values that match the tool's documented default, adding noise without
information. **Flag when:**

- The value is the documented default for the tool
- The setting adds no clarity for the reader
- The project does not have a convention of being explicit about defaults

**Keep when:**

- The default is surprising or has changed between versions
- The project intentionally documents all settings for auditability

### Promotional Comments in Configs

Marketing-style comments in configuration files. **Flag:**

- "This robust configuration ensures..."
- "Optimized for production workloads"
- "Enterprise-grade security settings"
- "Best-practice configuration for..."
- Any adjective-heavy comment that conveys no technical information

**Suggest:** Delete the comment. Config comments should explain non-obvious
choices, not sell the configuration.
