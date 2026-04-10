# Config and Infrastructure Slop Patterns

Patterns to identify and remove in AI-generated configuration files, CI
pipelines, Dockerfiles, IaC templates, and similar structured files.

## Narrating Comments

AI comments every field, including self-explanatory ones.

**Remove comments that:**

- Restate the key name: `# Set the port number` above `port: 8080`
- Explain standard fields: `# The name of the service` above `name: api`
- Describe what a well-known directive does: `# Expose port 443` above
  `EXPOSE 443`
- Add filler: `# Configure the database connection` above a `database:` block

**Keep comments that:**

- Explain _why_ a non-obvious value was chosen: `# 512Mi matches p95 usage`
- Warn about gotchas: `# Order matters — this must come before the COPY`
- Note environment-specific overrides
- Document workarounds for known issues

## Defensive Defaults

AI adds extra fallbacks, error handling, and retry logic that's unnecessary for
the deployment context.

**Remove when:**

- Health check has retries/intervals copied from a generic template without
  matching the actual service's startup behavior
- `restart: always` on every service including one-shot tasks
- Multiple redundant fallback env vars (`${VAR:-${OTHER_VAR:-default}}`) when
  one level suffices
- Catch-all error handlers in CI that swallow useful output

## Over-Structured YAML/JSON

AI splits simple configs into deeply nested hierarchies when a flat structure
would be idiomatic.

**Simplify when:**

- A single value is wrapped in multiple layers of nesting
- Arrays of one item are used where a scalar works
- Anchors and aliases are used for blocks that appear only once
- Separate files exist for configs that belong together

## Template Pollution

AI inserts boilerplate sections that don't apply to the project.

**Remove:**

- CI steps for languages/tools not in the project
- Dockerfile stages that are never used in the build target
- Commented-out blocks for "optional" features with no explanation of when
  they'd be enabled
- Security scanning steps that reference tools not installed

**Keep** commented-out sections that follow the project's template conventions
(e.g. this handbook's templates use commented-out optional sections by design).

## Promotional Comments in Configs

AI sometimes adds marketing-style comments to config files.

**Remove:**

- "This robust configuration ensures..."
- "Optimized for production workloads"
- "Enterprise-grade security settings"
- "Best-practice configuration for..."
- Any adjective-heavy comment that doesn't convey technical information

## Redundant Explicit Defaults

AI explicitly sets values that are already the default, making the config
noisier without adding information.

**Remove when:**

- The value matches the tool's documented default
- The explicit setting adds no clarity for the reader
- The project doesn't have a convention of being explicit about defaults

**Keep when:**

- The default is surprising or has changed between versions
- The project intentionally documents all settings for auditability
