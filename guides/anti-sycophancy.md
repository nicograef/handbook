# Anti-Sycophancy Agent Setup

A registry: how this handbook's agent setup counters sycophancy.

- **Rules are linked, never restated** — each lives in exactly one canonical place.

## Countermeasure catalog

| Countermeasure | Counters | Where it lives |
|---|---|---|
| Tone rules — no praise openers, criticism plainly and first | Flattery & validation | [AGENTS.md](../AGENTS.md) → Communication; [claude/CLAUDE.md](../claude/CLAUDE.md) → Communication Style; [templates/AGENTS.md](../templates/AGENTS.md) → Communication |
| Hold under pushback — re-verify, flip only on evidence | Capitulation | Same three Communication sections; graded-quiz variant in [tutor](../.claude/skills/tutor/SKILL.md) → Constraints; per-step-review variant in [guided-implementation](../.claude/skills/guided-implementation/SKILL.md) → step 4 |
| "No issues found" is a valid answer | Manufactured criticism | [output-style.md](../.claude/skills/output-style.md) → Report shape; linked from [cleanup](../.claude/skills/cleanup/SKILL.md), [ux-review](../.claude/skills/ux-review/SKILL.md), [test-quality](../.claude/skills/test-quality/SKILL.md), [prune](../.claude/skills/prune/SKILL.md), [reflect](../.claude/skills/reflect/SKILL.md) |
| Evidence before agreement — verify feedback against the codebase before implementing it | Confirmation bias | [receiving-feedback](../.claude/skills/receiving-feedback/SKILL.md) |
| Verification contracts — claims need tool evidence from this session | Confirmation bias | [.claude/skills/quality.md](../.claude/skills/quality.md); [web-researcher](../.claude/agents/web-researcher.md) → Hard rules |
| Structured recommendations — every clarifying question names a recommended option | Confirmation bias | [clarify question rules](../.claude/skills/clarify/question-rules.md) |
| Gated decisions — the human keeps the wheel | User dependence | Confirm-before-apply in [cleanup](../.claude/skills/cleanup/SKILL.md), [reflect](../.claude/skills/reflect/SKILL.md) and [distill](../.claude/skills/distill/SKILL.md); pick-what-dies multi-select in [prune](../.claude/skills/prune/SKILL.md); scaffolded hints instead of answers in [tutor](../.claude/skills/tutor/SKILL.md) |
| Output-style contract — hard caps, banned preamble and hedges | Padded, unfalsifiable output | [.claude/skills/output-style.md](../.claude/skills/output-style.md) |

## Why prompts alone don't fix it

- A rule demanding criticism creates its own failure mode: manufactured findings.
- Every criticism rule therefore needs the matching null-result rule beside it.
