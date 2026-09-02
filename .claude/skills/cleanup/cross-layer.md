# Cross-Layer Consistency

The trace used by the cleanup skill's repo-wide mode and by
guided-implementation.

- Follow each representative flow end-to-end.
- Check that every layer still agrees on shapes, types, and validation rules.

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

## How to trace

frontend call → API client → HTTP handler → application service → repository
→ SQL.

- At every hop, confirm the shape entering the next layer matches what that
  layer expects.
- When shapes diverge, identify which layer is the source of truth.
- Report the misaligned layers against that source of truth.
- For generated code, regenerate from the schema.
