# Anti-Sycophancy Agent Setup

A stack-convention guide: how this handbook's agent setup counters sycophancy.

- **Sycophancy** — an LLM's tendency to tell the user what they want to hear.
- **Scope** — the countermeasures below, plus how to carry them into a new project.
- **Rules are linked, never restated** — each lives in exactly one canonical place.

## Countermeasure catalog

| Countermeasure | Counters | Where it lives |
|---|---|---|
| Tone rules — no praise openers, criticism plainly and first | Flattery & validation | [AGENTS.md](../AGENTS.md) → Communication; [claude/CLAUDE.md](../claude/CLAUDE.md) → Communication Style; [templates/AGENTS.md](../templates/AGENTS.md) → Communication |
| Hold under pushback — re-verify, flip only on evidence | Capitulation | Same three Communication sections; graded-quiz variant in [tutor](../.claude/skills/tutor/SKILL.md) → Constraints; per-step-review variant in [guided-implementation](../.claude/skills/guided-implementation/SKILL.md) → step 5 |
| "No issues found" is a valid answer | Manufactured criticism | Same three Communication sections; per-skill variants in [cleanup](../.claude/skills/cleanup/SKILL.md), [ux-review](../.claude/skills/ux-review/SKILL.md), [test-quality](../.claude/skills/test-quality/SKILL.md), [prune](../.claude/skills/prune/SKILL.md), [reflect](../.claude/skills/reflect/SKILL.md) |
| Evidence before agreement — verify feedback against the codebase before implementing it | Confirmation bias | [receiving-feedback](../.claude/skills/receiving-feedback/SKILL.md) |
| Verification contracts — claims need tool evidence from this session | Confirmation bias | [.claude/skills/quality.md](../.claude/skills/quality.md); [web-researcher](../.claude/agents/web-researcher.md) → Hard rules |
| Structured recommendations — every clarifying question names a recommended option | Confirmation bias | [clarify question rules](../.claude/skills/clarify/question-rules.md) |
| Gated decisions — the human keeps the wheel | User dependence | Confirm-before-apply in [cleanup](../.claude/skills/cleanup/SKILL.md), [reflect](../.claude/skills/reflect/SKILL.md) and [distill](../.claude/skills/distill/SKILL.md); pick-what-dies multi-select in [prune](../.claude/skills/prune/SKILL.md); scaffolded hints instead of answers in [tutor](../.claude/skills/tutor/SKILL.md) |
| Output-style contract — hard caps, banned preamble and hedges | Padded, unfalsifiable output | [.claude/skills/output-style.md](../.claude/skills/output-style.md) |

## Why prompts alone don't fix it

- A rule demanding criticism creates its own failure mode: manufactured findings.
- Every criticism rule therefore needs the matching null-result rule beside it.

## Applying to a new project

1. Copy [templates/AGENTS.md](../templates/AGENTS.md) — its Communication section already
   carries the rules ([new-project.md](new-project.md), step 5).
2. The global rules travel with the dotfiles: `~/.claude/CLAUDE.md` is a symlink into this
   repo ([dotfiles-codespaces.md](dotfiles-codespaces.md)) — nothing to copy per project.
3. Skills with per-skill guards travel via the plugin or skill symlinks
   ([claude-plugin.md](claude-plugin.md), [copilot-agent-setup.md](copilot-agent-setup.md)).
4. New review- or grading-style skill — add both guards to its Constraints:
   zero-findings-valid and hold-under-pushback.
   - Copy the pattern from [cleanup](../.claude/skills/cleanup/SKILL.md) step 4 and
     [tutor](../.claude/skills/tutor/SKILL.md) Constraints.
