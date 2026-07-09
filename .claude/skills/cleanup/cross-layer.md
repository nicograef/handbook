# Cross-Layer Consistency

The trace used by the cleanup skill's repo-wide scope mode. Follow each
representative flow end-to-end and check that every layer still agrees on
shapes, types, and validation rules.

- [Do the layers agree?](#do-the-layers-agree)
- [How to trace](#how-to-trace)
- [Simplification pass](#simplification-pass)

---

## Do the layers agree?

- Frontend request bodies vs. backend handler request structs
- Frontend response parsing vs. backend response JSON shapes
- Frontend types and validation schemas vs. backend types and JSON payloads
- Database queries vs. schema (columns, nullability, defaults, status values)
- Generated query expectations vs. repository mapping
- Validation rules consistent on both sides (e.g. max length 50 in UI but 255
  in DB)
- Status values or enum options consistent across layers
- A generated API client in sync with the actual API

---

## How to trace

Pick 3–5 representative flows per feature area and follow each one end-to-end:

frontend call → API client → HTTP handler → application service → repository
→ SQL.

At every hop, confirm the shape entering the next layer matches what that layer
expects. When shapes diverge, identify which layer is the source of truth and
align the others to it. For generated code, regenerate from the schema.

---

## Simplification pass

While tracing, note anything harder to read than necessary:

- Long, nested logic that can be flattened
- Interfaces with only one implementation that add indirection without value
- Wrapper functions that only forward calls
- Stale patterns left over from an earlier architecture phase
- Unused code, dead exports, endpoints nothing calls
- Inconsistent style across similar modules
- Queries that are unnecessarily complex
- Repository methods that only forward generated queries without domain value

Keep these suggestions readability-first — do not propose rewrites that trade
clarity for cleverness or brevity. Do not flag a single-implementation
interface or a wrapper unless it adds indirection without value; some
abstractions are intentional (see the boundary exceptions in
[architecture.md](architecture.md) and [code-smells.md](code-smells.md)).
