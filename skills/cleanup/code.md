# Code Slop Patterns

Patterns to identify and remove in AI-generated code. Each pattern includes
what to look for and what to do about it.

## Unnecessary Comments

AI adds comments that a human developer wouldn't write — restating what the
code already says, explaining obvious operations, or narrating control flow.

**Remove when:**

- Comment restates the code: `// increment counter` above `counter++`
- Comment explains language basics: `// loop through items`
- Comment adds a "section header" that doesn't match the file's existing style
- Comment uses promotional tone: `// elegant solution for...`
- Comment describes intent that's already clear from naming

**Keep when:**

- Comment explains a non-obvious _why_ (business rule, workaround, edge case)
- Comment matches the existing documentation density of the file

## Defensive Overkill

AI wraps everything in safety nets — nil checks, try/catch, error guards — even
when the caller already guarantees validity or the surrounding code trusts its
inputs.

**Remove when:**

- A nil/null check guards a value that was just constructed or validated
- A try/catch wraps code that cannot throw in the current context
- Error handling duplicates what an outer layer already catches
- A defensive check doesn't match the trust model of surrounding code (e.g.
  internal service method validates like a public API handler)
- Guard clauses are added for impossible states

**Keep when:**

- The check is at a system boundary (HTTP handler, CLI input, external API call)
- The surrounding code has the same defensive style (it's the project's norm)

## Type Escape Hatches

AI reaches for type-system workarounds to make code compile fast.

**Remove:**

- `any` casts in TypeScript (`as any`, `<any>`)
- `interface{}` where a concrete type exists (Go)
- `// @ts-ignore`, `// @ts-expect-error` without explanation
- `# type: ignore` in Python without a specific error code
- `@SuppressWarnings` in Java without justification
- Force-unwraps or `!` assertions that bypass null safety
- Generic `Object` types where a specific type is available

**Replace with** the correct type or fix the underlying type issue.

## Redundant Abstractions

AI creates unnecessary indirection — wrapper functions that only forward calls,
interfaces with a single implementation, factory functions for one-time use.

**Remove when:**

- A function's entire body is a single forwarded call
- An interface has exactly one implementation and no test double
- A factory does nothing beyond calling a constructor
- A helper exists for a one-time operation
- A utility module wraps standard library functions without adding value

## Unnecessary Complexity

AI over-engineers simple operations with excessive nesting, premature
abstraction, or convoluted control flow.

**Simplify when:**

- Nested if/else can be replaced with early returns or guard clauses
- A chain of map/filter/reduce is less readable than a simple loop
- A switch/match has been extracted into a strategy pattern for 2 cases
- Promise chains are used where async/await would be clearer
- Boolean logic uses double negation or unnecessary ternaries

## Style Drift

AI introduces patterns from other codebases or languages that clash with the
project's conventions.

**Watch for:**

- Naming conventions that don't match (camelCase in a snake_case project)
- Import styles that differ from the rest of the file
- Error handling patterns imported from another language (e.g. Go-style
  `if err != nil` rewritten as try/catch in TypeScript)
- Logging patterns that don't use the project's logger
- String formatting style that differs (template literals vs concatenation)
- Brace style or indentation that doesn't match

## Over-Engineered Error Messages

AI writes error messages like documentation — long, multi-sentence, sometimes
with suggestions for how to fix the problem.

**Simplify to** match the project's existing error message style. Usually a
short, specific description is sufficient.

## Verbose Variable Names

AI sometimes creates excessively descriptive variable names that read like
sentences.

**Shorten when:**

- `filteredAndSortedUserListForDisplay` → `sortedUsers`
- `isCurrentlyBeingProcessed` → `processing`
- The name is longer than the scope warrants (one-liner lambda, loop body)

**Keep** descriptive names in wider scopes where clarity matters.
