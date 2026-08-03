# Evaluation Criteria

Use this rubric during Step 2 (Audit) to tag each test as **Keep**,
**Refactor**, **Delete**, or **Merge**.

## Decision Tree

```
1. Does the test make at least one meaningful assertion?
   └─ NO  → DELETE (Tests That Never Fail)

2. Does the test assert only on values the test itself created,
   with no non-trivial logic from the system?
   └─ YES → DELETE (Asserting on Setup Values)

3. Does the test access private/unexported methods or fields directly?
   └─ YES → DELETE (replace with a public-API test if the behavior matters)

4. Does the test assert on internal call counts, argument order,
   or mock invocations of code you own?
   └─ YES → DELETE (or REFACTOR if the same behavior can be verified via output)

5. Does the test mock internal collaborators (classes/modules you own)?
   └─ YES → REFACTOR (replace mocks with real or in-memory implementations)

6. Does the test verify state by bypassing the public interface
   (raw SQL, file reads, internal object inspection)?
   └─ YES → REFACTOR (verify through the public interface instead)

7. Is the test name phrased as HOW the system works
   ("calls X", "invokes Y", "sets flag Z") rather than WHAT it does?
   └─ YES → likely REFACTOR (rewrite intent + implementation)

8. Does an identical behavior already have 2+ other tests
   with only trivially different inputs?
   └─ YES → MERGE (keep one; fold the others into a table-driven test)

9. Does the test over-specify error messages (exact string match)?
   └─ YES → REFACTOR (assert on type / code instead)

All NO → KEEP
```

## Coverage Loss Protocol

**Trigger**: a Delete tag removes the only test for a behavior.

1. **Note** it explicitly in the Step 3 report, in this shape:
   ```
   ⚠ Delete "test name" removes the only coverage for [behavior X].
     Suggest: add a proper test via TDD skill after this review.
   ```
2. **Skip** the replacement test — adding it is out of scope for this skill.
3. **Confirm** with the user before deleting.
