# React Frontend

General guide for building React frontends with TypeScript and Vite. Derived from [nicograef/lexiban](https://github.com/nicograef/lexiban).

---

## Setup

Scaffold with [Vite](https://vitejs.dev) and the React + TypeScript template:

```bash
pnpm create vite my-app --template react-ts
cd my-app
pnpm install
pnpm dev
```

Key tools in the stack:

| Tool | Purpose |
| ---- | ------- |
| Vite | Build tool and dev server |
| React 19 | UI framework |
| TypeScript | Static typing |
| Tailwind CSS | Utility-first styling |
| shadcn/ui | Accessible component primitives (Radix UI) |
| Zod | Runtime schema validation |
| ESLint + Prettier | Linting and formatting |
| Vitest + Testing Library | Unit and component tests |

---

## Project Structure

Use a **feature-based** structure. Each feature owns its components, hooks, types, API calls, and utilities.

```
src/
  features/
    iban/
      IbanPage.tsx        # route-level page component
      IbanInput.tsx       # feature-specific component
      IbanList.tsx
      hooks.ts            # feature-specific hooks
      api.ts              # API calls for this feature
      types.ts            # TypeScript types
      utils.ts            # pure utility functions
      utils.test.ts       # co-located tests
  components/             # shared, reusable UI components
  hooks/                  # shared hooks (e.g. useFetch)
  lib/                    # shared utilities (cn helper, etc.)
  App.tsx
  main.tsx
```

Avoid large `utils/` or `helpers/` directories — put code near the feature that owns it.

---

## TypeScript

Define explicit types for all domain data. Prefer `type` for data shapes, `interface` when extension is expected.

```ts
// types.ts
export type ValidationResult = {
  valid: boolean;
  iban: string;
  bankName: string | null;
  error: string | null;
};
```

Use **Zod** to validate external data (API responses, form inputs) at runtime:

```ts
import { z } from "zod";

const ValidationResultSchema = z.object({
  valid: z.boolean(),
  iban: z.string(),
  bankName: z.string().nullable(),
  error: z.string().nullable(),
});

export type ValidationResult = z.infer<typeof ValidationResultSchema>;
```

Enable `strict: true` in `tsconfig.json`.

---

## Components

Write small, focused functional components. Each component has one job.

- **Page components** — own the state and data fetching, compose smaller components
- **Presentational components** — receive props, render UI, no side effects
- Keep components in the feature folder they belong to; move to `components/` only when reused across features

```tsx
// IbanInput.tsx — owns form state, delegates to API hook
export function IbanInput() {
  const { validate, result, isLoading } = useIbanValidation();
  return <form onSubmit={...}>...</form>;
}

// ValidationResult.tsx — pure display component
export function ValidationResult({ result }: { result: ValidationResult }) {
  return <div>{result.valid ? "Valid" : result.error}</div>;
}
```

---

## Custom Hooks

Extract side effects and shared logic into custom hooks. A hook encapsulates state + behavior together.

```ts
// hooks/useFetch.ts — generic data fetching hook
export function useFetch<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // fetch logic...

  return { data, isLoading, error };
}
```

Feature-specific hooks live in the feature folder (`features/iban/hooks.ts`). Generic hooks live in `hooks/`.

---

## API Calls

Keep all API calls in a dedicated `api.ts` file per feature. No `fetch` calls inside components.

```ts
// features/iban/api.ts
const API_BASE = import.meta.env.VITE_API_URL;

export async function validateIban(iban: string): Promise<ValidationResult> {
  const res = await fetch(`${API_BASE}/api/ibans`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ iban }),
  });
  if (!res.ok) throw new Error("Request failed");
  return ValidationResultSchema.parse(await res.json());
}
```

Always validate API responses with Zod — never trust raw JSON.

---

## Styling

Use **Tailwind CSS** utility classes directly in JSX. Use the `cn()` helper (from `clsx` + `tailwind-merge`) to conditionally combine classes:

```ts
// lib/utils.ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

Use **shadcn/ui** for complex interactive components (dialogs, forms, buttons). Add components with:

```bash
pnpm dlx shadcn@latest add button input card
```

---

## Formatting and Linting

Configure **Prettier** and **ESLint** together. ESLint handles code quality; Prettier handles formatting.

`.prettierrc`:
```json
{ "singleQuote": true, "semi": false }
```

Run checks:

```bash
pnpm lint       # eslint --fix --max-warnings=0
pnpm format     # prettier --write .
pnpm build      # tsc -b && vite build — catches type errors
```

Use `eslint-config-prettier` to disable ESLint rules that conflict with Prettier. Use `eslint-plugin-simple-import-sort` for consistent import ordering.

---

## Testing

Use **Vitest** as the test runner and **React Testing Library** for component tests. Co-locate test files with the code they test.

| What to test | Tool |
| ------------ | ---- |
| Pure functions / utils | Plain Vitest (`describe` / `it`) |
| Custom hooks | `renderHook` from Testing Library |
| Components | `render` + user-event from Testing Library |

Key rules:

- Test **behavior**, not implementation — interact with the DOM as a user would
- Use `screen.getByRole`, `screen.getByText` — avoid querying by class or implementation detail
- Mock `fetch` or API modules for component tests that trigger network calls
- Run with `pnpm test`; watch mode with `pnpm test:watch`
