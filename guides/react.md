# React Frontend Guide

Stack-convention guide for React + TypeScript frontend projects — heading-grouped rules, not a runbook.

## Project Setup

Use **Vite** as the build tool and **pnpm** as the package manager.

Enforce engine versions in `package.json`:

```json
"engines": { "node": ">=24", "pnpm": ">=10" }
```

Use `--frozen-lockfile` in CI to guarantee reproducible installs.

## Project Structure

Organise by feature, not by type. Avoid deep nesting.

```
src/
  components/    # shared, reusable UI components
  pages/         # one file per route
  hooks/         # custom hooks (data fetching, local state)
  service/       # API calls and data-access abstractions
  lib/           # utility functions, formatters, helpers
  test/          # shared test utilities and setup
```

Feature-specific components live next to the page that owns them. Move to `components/` only when shared across multiple pages.

## TypeScript

Enable strict mode in `tsconfig.json`. No `any` — use `unknown` and narrow explicitly.

Prefer explicit return types on non-trivial functions. Use `zod` to define and validate data schemas at API boundaries — this gives you runtime safety and inferred TypeScript types from a single source.

## Linting

Use **ESLint** with:

| Plugin | Purpose |
| --- | --- |
| `typescript-eslint` | TypeScript-aware rules |
| `eslint-plugin-react-hooks` | Hooks rules (exhaustive deps) |
| `eslint-plugin-react-x` | React best practices |
| `simple-import-sort` | Consistent import ordering |
| `eslint-config-prettier` | Disable ESLint rules that conflict with Prettier |

Run with `--max-warnings=0` to treat warnings as errors:

```bash
pnpm lint
```

Combine lint + format checks before running tests in CI.

## Component Design

- Prefer small, focused components. If a component is hard to name, it probably does too much.
- Keep UI components free of data-fetching logic. Fetch in hooks or pages, pass data as props.
- Use **shadcn/ui** for complex interactive components (dialogs, forms, buttons) — built on Radix UI primitives, styled with Tailwind CSS. Add components with `pnpm dlx shadcn@latest add button input card`.
- Use the `cn()` helper (`clsx` + `tailwind-merge`) to conditionally combine Tailwind classes without conflicts.
- Co-locate component-specific helpers, types, and sub-components in the same file or directory — only extract when reused.

## API Layer

Keep all API calls in a dedicated `api.ts` file per feature or in `service/`. No `fetch` calls inside components or hooks — components receive data, hooks orchestrate calls.

Always validate API responses with **Zod** — never trust raw JSON.

## Testing

Use **Vitest** + **@testing-library/react**.

Test behaviour, not implementation. Query elements the way a user would (by role, label, text). Avoid testing internal state or implementation details.

Test utility setup (global mocks, render wrappers) goes in `src/test/`.

See [guides/github-actions-cicd.md](github-actions-cicd.md) for the frontend CI job with lint, build, and test steps.
