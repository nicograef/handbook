# Quality Checklist

Shared verification contract for the handbook skills. Skills that produce code or
documents link here from their **Quality** section instead of restating it. Run it
once per result — surface issues in the chat only if you find them.

## Scope guard

Scope is the user's call. Do not silently widen it — and do not stop the run to
report that you noticed.

- A change the task needs but did not name: make it, and name it in the report.
- A change the task does not need: leave it, and name it in the report.
- Neither ends the turn. Finish the scope you were given first.
- Stop mid-run only when continuing would destroy something, or when every
  remaining step is out of scope.
- Questions about scope clear the [ask gate](clarify/question-rules.md#the-ask-gate)
  like any other.

## Verify before claiming done

Before reporting work as complete, audit each claim against a tool result from
this session.

- Code changes: name the exact test/build/lint command, run it fresh this
  turn, and cite its output.
- Document artifacts: re-read the final file and confirm every link and path
  it references exists.

## Supersede check

Before reporting work complete, retire what your change made false. This enforces
the **Current state only** rule in [`AGENTS.md`](../../AGENTS.md).

- Search docs, comments, instructions and memory for the statement you replaced.
- Rewrite or delete every hit in the same change.
- Cite the hit that proves the statement superseded; a suspicion is not one.
- Delete nothing without that citation.
- Report retirements beside additions: what you added, what you retired.
- Nothing to retire is a valid result. State it in one line.
