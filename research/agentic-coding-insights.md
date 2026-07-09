# Agentic Coding Setup — Research Reference & Audit Yardstick

This document distills verified research (all sources re-checked live as of 2026-07-09) on Claude Code, prompt engineering for current frontier models, context engineering, harness engineering, GitHub Copilot customization, and multi-agent orchestration. It is the canonical reference for overhauling the handbook's agentic coding setup (CLAUDE.md / AGENTS.md, 17 skills, agents/, commands/, claude/ dotfiles, .github Copilot files) and doubles as the audit checklist for reviewing that setup. Every insight carries its source inline; claims that could not be verified live are marked "not verified".

---

## 1. Claude Code: memory, rules, skills, agents, hooks, settings

### Canonical docs moved

- Docs now live at `code.claude.com/docs`. The 2025 "Claude Code Best Practices" engineering article 308-redirects to [code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices); `docs.claude.com/en/docs/claude-code/*` 301-redirects to `code.claude.com/en/*`. Update all handbook links; re-base any notes summarizing the old article on the current living doc (which added `/goal`, Stop hooks, auto mode).
- Platform-level skill-authoring guidance lives separately at [platform.claude.com — Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

### CLAUDE.md rules

- Target **under 200 lines** per CLAUDE.md. Longer files reduce adherence: "Bloated CLAUDE.md files cause Claude to ignore your actual instructions." ([memory docs](https://code.claude.com/docs/en/memory), [best practices](https://code.claude.com/docs/en/best-practices))
- Per-line removal test: "Would removing this cause Claude to make mistakes?" If not, cut it.
- Include: commands Claude can't guess, style rules differing from defaults, repo etiquette, environment gotchas. Exclude: anything inferable from code, standard conventions, API docs, frequently-changing info, file-by-file codebase descriptions.
- Instructions must be verifiable: "Run npm test before committing", not "test your changes". Contradictions across files cause arbitrary rule-picking.
- Multi-step procedures do NOT belong in CLAUDE.md — they belong in a skill. Directory-specific conventions belong in path-scoped rules.
- `@path` imports (max depth 4 hops) organize content but **save zero context** — imported files load in full at launch.
- Block-level HTML comments are stripped before injection — free maintainer notes (comments inside code fences are preserved).
- CLAUDE.md is advisory (injected as a user message); anything that must always happen belongs in a hook.

### CLAUDE.md hierarchy and compaction survival

- Load order (additive, root-down, most specific last): managed policy (`/etc/claude-code/CLAUDE.md`) → user (`~/.claude/CLAUDE.md`) → project (`./CLAUDE.md` or `./.claude/CLAUDE.md`) → `./CLAUDE.local.md` (gitignored, personal). ([memory docs](https://code.claude.com/docs/en/memory))
- Subdirectory CLAUDE.md files lazy-load only when Claude reads files there.
- Compaction survival table ([context window docs](https://code.claude.com/docs/en/context-window)): project-root CLAUDE.md, unscoped rules, and auto memory are re-injected from disk; path-scoped rules and nested CLAUDE.md files are lost until a matching file is read again; the skill listing is NOT re-injected — only invoked skills persist (capped 5,000 tokens per skill, 25,000 total, oldest dropped first). Rules that must never be lost mid-session (no auto-commit, no `--force` push) belong in project-root CLAUDE.md.
- Steer `/compact` from CLAUDE.md, e.g. "When compacting, always preserve the full list of modified files and any test commands."
- `claudeMdExcludes` (glob patterns) skips irrelevant CLAUDE.md files in monorepos.

### AGENTS.md interop — single source of truth

- **Claude Code does not read AGENTS.md.** Official pattern: make AGENTS.md canonical and create a CLAUDE.md whose first line is `@AGENTS.md` (Claude-specific rules below it), or `ln -s AGENTS.md CLAUDE.md` when nothing Claude-specific exists. ([memory docs](https://code.claude.com/docs/en/memory))
- AGENTS.md is the cross-tool standard (Agentic AI Foundation / Linux Foundation, 20+ tools incl. Copilot, Codex, Cursor, Zed; used by 60k+ OSS projects). Plain Markdown, no required structure; nearest AGENTS.md wins in monorepos; agents are expected to run any programmatic checks listed in it. ([agents.md](https://agents.md/))
- Never maintain two diverging instruction sets — the handbook currently has separate CLAUDE.md and AGENTS.md, a drift risk.

### Path-scoped rules: .claude/rules/

- Markdown files in `.claude/rules/` (discovered recursively, one topic per file, symlinks supported) load at the same priority as `.claude/CLAUDE.md`. YAML frontmatter `paths:` with globs (brace expansion supported) makes a rule load **only** when Claude works on matching files — the official fix for oversized CLAUDE.md. ([memory docs](https://code.claude.com/docs/en/memory))
- User-level rules: `~/.claude/rules/` (project wins on conflict).
- This is the Claude Code analog of Copilot's `applyTo`-scoped `*.instructions.md` — mirror the two structures.
- Caveat: path-scoped rules are summarized away on compaction; always-on rules stay in root CLAUDE.md.

### Auto memory

- On by default (v2.1.59+); toggle via `/memory`, `autoMemoryEnabled`, or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. Storage per git repo (shared across worktrees) at `~/.claude/projects/<project>/memory/`, relocatable via `autoMemoryDirectory`. ([memory docs](https://code.claude.com/docs/en/memory))
- Only the **first 200 lines or 25KB** of MEMORY.md load at startup; topic files load on demand. Keep MEMORY.md a concise index.
- Define a promotion path: recurring memory entries get human-reviewed and promoted into committed AGENTS.md / rules / skills, then deleted from memory. Official promotion triggers: same mistake twice, review catches something Claude should have known, retyping last session's correction.

### Skills (SKILL.md)

- **Commands are merged into skills.** `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy`; skills are recommended (supporting files, invocation control, auto-triggering); skill wins on name conflict. ([skills docs](https://code.claude.com/docs/en/skills))
- Frontmatter spec (Claude Code): all fields optional; documented fields include `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context` (fork), `agent`, `hooks`, `paths`, `shell`. **There is no `tools` field for skills** — that belongs to subagent frontmatter; the tool-approval field is `allowed-tools`. ([skills docs](https://code.claude.com/docs/en/skills))
- Open-standard validation ([agentskills.io spec](https://agentskills.io/specification)): `name` ≤64 chars, lowercase letters/numbers/hyphens only, must match the directory name, no "anthropic"/"claude"; `description` non-empty, ≤1024 chars, no XML tags. Invalid names **silently fail to load** in VS Code.
- Descriptions: third person ("Processes X…", never "I can help…"), state **what + when** with concrete trigger keywords, key use case in the first sentence. ([authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices))
- Listing budget: combined `description` + `when_to_use` truncated at 1,536 chars per skill (`skillListingMaxDescChars`); whole listing budgeted at 1% of context (`skillListingBudgetFraction`); least-used skills lose descriptions first. Run `/doctor` to see which are shortened or dropped.
- Progressive disclosure: SKILL.md body **under 500 lines** (<5,000 tokens recommended), bundled references **exactly one level deep** from SKILL.md (nested chains cause partial `head -100` reads), reference files >100 lines start with a TOC, files named descriptively (`form_validation_rules.md`, not `doc2.md`), and state whether a bundled script is executed ("Run analyze_form.py") or read. Critical content first — post-compaction truncation keeps the start of the file. ([authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [skills docs](https://code.claude.com/docs/en/skills), [Anthropic engineering](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills))
- Invocation control: `disable-model-invocation: true` = user-only, description removed from context entirely (zero token cost) — recommended for side-effect workflows (/commit, /deploy). `user-invocable: false` = model-only background knowledge, hidden from the `/` menu. Permission rules `Skill(name)` and `skillOverrides` give per-skill control. These are Claude Code extensions — Copilot may ignore them; don't rely on them as a safety mechanism cross-tool. ([skills docs](https://code.claude.com/docs/en/skills))
- Evals are official practice: create evaluations **before** extensive docs (≥3 scenarios per skill), establish a no-skill baseline, iterate; the skill-creator plugin stores `evals/evals.json` per skill, runs isolated graded runs, and tunes descriptions with should-trigger / should-not-trigger prompts. Watch real navigation: over-read files → inline the content; never-read files → delete. Test with every model and every consumer you use. ([authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [skills docs](https://code.claude.com/docs/en/skills))
- Degrees of freedom rubric: high freedom (heuristics) for open-ended review tasks; medium (templates) when a preferred pattern exists; low ("Run exactly this command, do not modify") for fragile sequences. One default + explicit escape hatch, not menus of alternatives. One term per concept. No date-bound statements in skill bodies.

### Subagents (.claude/agents/)

- Markdown files in `.claude/agents/` (project) or `~/.claude/agents/` (user); precedence managed > `--agents` CLI > project > user > plugin. Required: `name` (lowercase-hyphen) + `description` (delegation criteria — "Use proactively after code changes"). Optional: `tools`, `disallowedTools`, `model` (default inherit), `permissionMode`, `maxTurns`, `skills` (full skill content preloaded), `mcpServers` (inline servers live only for the subagent — keeps schemas out of the main context), `hooks`, `memory` (user/project/local; project = shareable via version control), `background`, `effort`, `isolation: worktree`, `color`, `initialPrompt`. Body = system prompt; subagents do NOT get the full Claude Code prompt. `/agents` wizard removed in v2.1.198 — edit files directly. ([subagents docs](https://code.claude.com/docs/en/sub-agents))
- Reviewer/verifier agents should be read-only: `tools: Read, Grep, Glob, Bash` — no Edit/Write.
- Subagent startup context: own system prompt + environment, delegation message, CLAUDE.md/memory, git-status snapshot, preloaded skills. NOT: conversation history, previously read files, invoked skills. Built-in Explore/Plan agents additionally skip CLAUDE.md and git status — repo rules must be restated in the delegation prompt.

### Hooks — the enforcement layer

- "An instruction like never edit .env in CLAUDE.md or a skill is a request, not a guarantee. A PreToolUse hook that blocks the edit is enforcement." ([features overview](https://code.claude.com/docs/en/features-overview))
- 31 hook events (PreToolUse, PostToolUse, UserPromptSubmit, Stop, SessionStart, PreCompact, InstructionsLoaded, …); handler types command, prompt, http, mcp_tool, agent. Exit code 0 = success (JSON parsed); **exit code 2 = blocking** (stderr fed to Claude); exit code 1 is non-blocking. A Stop hook can gate turn-end on a passing check; Claude Code overrides after 8 consecutive blocks. ([hooks reference](https://code.claude.com/docs/en/hooks), [best practices](https://code.claude.com/docs/en/best-practices))
- Convert enforceable "must/never" prose (no `--force` push, no `--no-verify`, don't commit) into PreToolUse hooks; keep only judgment-based rules as prose.

### Settings and the decision framework

- Settings precedence: managed > CLI args > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json`. Add `"$schema": "https://json.schemastore.org/claude-code-settings.json"` for editor validation. MCP servers: `.mcp.json` (project, committed) or `~/.claude.json`. ([settings docs](https://code.claude.com/docs/en/settings))
- Official decision table for where content goes ([features overview](https://code.claude.com/docs/en/features-overview)): convention wrong twice → CLAUDE.md; same prompt repeatedly → user-invocable skill; repeated playbook → skill; browser-copied data → MCP; noisy side task → subagent; must-happen-every-time → hook; second repo needs same setup → plugin. Every piece of agentic content should map to exactly one row.

### Sandbox and devcontainers

- Native `/sandbox` Bash sandbox (bubblewrap + socat on Linux; optional seccomp): OS-enforced write-to-cwd-only, default-deny network with per-domain prompts (`sandbox.network.allowedDomains`), `sandbox.credentials` to deny/mask secrets — note the default read policy still allows `~/.ssh` and `~/.aws/credentials` unless denied. Sandbox denies writes to all settings.json scopes (self-protecting). Ubuntu 24.04+ needs an AppArmor bwrap profile when `apparmor_restrict_unprivileged_userns=1`; docker and watchman are incompatible. ([sandboxing docs](https://code.claude.com/docs/en/sandboxing))
- Devcontainers are the sanctioned path to `--dangerously-skip-permissions`: feature `ghcr.io/anthropics/devcontainer-features/claude-code:1.0`, config volume `claude-code-config-${devcontainerId}`, `init-firewall.sh` egress restriction (NET_ADMIN/NET_RAW), non-root `remoteUser` (the flag is rejected as root). Never mount `~/.ssh` or cloud credentials — a malicious repo can exfiltrate anything in the container. Pin versions + `DISABLE_AUTOUPDATER=1`. ([devcontainer docs](https://code.claude.com/docs/en/devcontainer), [reference .devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer))

---

## 2. Prompt engineering for current models

### Docs consolidation

- All per-technique pages (be-clear-and-direct, use-xml-tags, chain-of-thought, long-context-tips, …) merged into one living reference: [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices). Old docs.anthropic.com / docs.claude.com URLs redirect to platform.claude.com. Update all handbook links; restructure any cheatsheet mirroring the old page layout.

### What still works unchanged

- Colleague test ("If they'd be confused, Claude will be too"), 3–5 diverse examples in `<example>`/`<examples>` tags, consistent descriptive XML section tags, numbered lists when order/completeness matters. ([best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))
- Role prompting demoted to a **single functional sentence** in the system prompt — cut elaborate persona blocks ("world-class expert with 20 years…").
- Long-context rule survives, quantified: at 20k+ tokens put longform data at the TOP and query/instructions at the END (up to **30% quality gain**); wrap documents in `<documents>/<document index>` XML; ask for relevant quotes first (`<quotes>`) to ground long-document tasks.

### What changed with the newest generation

- **Literal instruction following.** Models "do not silently generalize an instruction from one item to another". State scope explicitly ("Apply this to every section, not just the first"). Replace qualitative bars ("only report important issues", "don't nitpick" — these now suppress findings and drop recall) with concrete ones ("report any bug that could cause incorrect behavior, a test failure, or a misleading result; omit pure style nits"). Positive instructions beat negative ones. ([Opus 4.8 page](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8), [Sonnet 5 page](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5))
- **De-escalate emphasis.** "CRITICAL: You MUST use this tool when…" and "If in doubt, use [tool]" now cause overtriggering. Use plain conditionals: "Use this tool when…". Tune anti-laziness prompting downward. ([best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))
- **Cut compensation scaffolding.** "Skills developed for prior models are often too prescriptive for Claude Fable 5 and can degrade output quality." Delete workarounds for gaps models no longer have (micro-step decomposition, "summarize after every 3 tool calls", defensive self-verify loops, redundant few-shot); keep contract scaffolding (output schemas, policy guardrails, idempotency rules) that enforces guarantees regardless of model strength. ([Fable 5 page](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5); practitioner framing: [keepmyprompts.com](https://www.keepmyprompts.com/en/blog/claude-fable-5-cut-prompt-scaffolding-2026))
- **Never ask the model to echo its reasoning.** "Show your thinking / transcribe your thought process" instructions trigger the `reasoning_extraction` refusal category on Fable 5 (elevated fallbacks to Opus 4.8). Ask for a rationale of the *result* instead. ([Fable 5 page](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5))
- **Chain-of-thought is a fallback.** "Think thoroughly" beats hand-written reasoning plans; adaptive thinking + the `effort` parameter (low→max) replace `budget_tokens` (400 error on Opus 4.7+/Fable 5/Sonnet 5). Manual `<thinking>/<answer>` CoT only when thinking is off. Quirk: with thinking off, Opus 4.5 is sensitive to the word "think" — use "consider"/"evaluate". ([best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))
- **Prefill is dead.** Prefilled assistant turns return a 400 on Claude 4.6+. Migrate: JSON forcing → Structured Outputs or schema instructions; preamble elimination → "Respond directly without preamble"; continuations → move text into the user message. ([best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))
- **Explicit quality bar.** Models no longer pad by default; request "above and beyond" explicitly ("Go beyond the basics to create a fully-featured implementation"). Terse by default: post-tool summaries must be requested.
- **Format control:** say what TO do, not what to avoid ("compose smoothly flowing prose paragraphs" > "don't use markdown"); XML format indicators; prompt style begets output style (markdown-heavy instructions → markdown-heavy answers).

### Official copy-ready blocks (adopt canonical phrasing)

- Anti-overengineering: "Only make changes that are directly requested or clearly necessary… Don't add error handling, fallbacks, or validation for scenarios that can't happen… Only validate at system boundaries… The right amount of complexity is the minimum needed for the current task."
- Anti-hallucination: `<investigate_before_answering>` — "Never speculate about code you have not opened."
- Anti-test-gaming: "Tests are there to verify correctness, not to define the solution." Temp-file cleanup block.
- Action defaults: paired `<default_to_action>` vs `<do_not_act_before_instructions>` blocks; boundary pattern for Fable 5 ("When the user is describing a problem… the deliverable is your assessment. Report your findings and stop."). Nico's no-auto-commit / drafts-stay-drafts rules are exactly this pattern — formalize with the official phrasing.
- Anti-fabrication (nearly eliminated fabricated status reports in Anthropic testing): "Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for." ([Fable 5 page](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5))
- All from [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) unless noted.

### Vendor-neutral hygiene (GPT-family, relevant because Copilot consumes the same skills)

- GPT-5 follows prompts "with surgical precision"; contradictory instructions are actively damaging (reasoning tokens burned reconciling them). Run a contradiction audit across the layered instruction surface (CLAUDE.md + AGENTS.md + copilot-instructions.md + *.instructions.md + SKILL.md); metaprompting (feed the merged set to the model, ask what conflicts) is officially endorsed. Migration discipline: switch models without changing prompts, baseline, then one change at a time. ([GPT-5 guide](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_prompting_guide), [GPT-5.2 guide](https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide))

---

## 3. Context engineering

- **Finite attention budget.** Context is "a precious, finite resource"; context rot degrades recall as tokens grow. Goal: "the smallest set of high-signal tokens that maximize the likelihood of your desired outcome" — minimal, not necessarily short. Default assumption: "Claude is already very smart"; challenge each paragraph's token cost (a ~50-token instruction beat a ~150-token one explaining what a PDF is). ([Anthropic: effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), [authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices))
- **Right altitude.** Two failure modes: brittle hardcoded pseudo-logic (too low) and vague platitudes assuming shared context (too high). Write strong heuristics in distinct sections (XML tags or headers). Start minimal on the best model; add instructions only in response to **observed failures**; a few diverse canonical examples, not "a laundry list of edge cases". Prune rules nobody remembers the reason for.
- **Just-in-time retrieval over pre-loading.** Maintain lightweight identifiers (paths, links); file names, folder hierarchy, and naming conventions are the retrieval index. Bundled skill files cost zero context until read. The handbook's README index, grep-first instructions, and verb-noun script names already form this layer — keep filenames self-describing, point to paths instead of inlining reference material.
- **Files are memory.** Structured note-taking (NOTES.md / plan.md checklists) is a core long-horizon technique; use JSON for state the agent must not rewrite ("the model is less likely to inappropriately change or overwrite JSON files compared to Markdown"). Session-start ritual: read git log + progress files before new work. ([long-running harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents))
- **Prefer fresh context over compaction** for long-horizon work: latest models "are extremely effective at discovering state from the local filesystem" — be prescriptive ("Review progress.txt, tests.json, and the git logs"). Selective context pruning is risky ("It is difficult to know which tokens the future turns will need") — favor durable, recoverable state outside the window. ([best practices](https://code.claude.com/docs/en/best-practices), [harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps), [managed agents](https://www.anthropic.com/engineering/managed-agents))
- **Session hygiene:** `/clear` between unrelated tasks; `/compact <focus>` before a long new task; `/context` for a live breakdown; after two failed corrections, `/clear` and rewrite the prompt instead of continuing.
- **Tool/MCP hygiene:** few consolidated, token-efficient tools with distinct purposes; concise-by-default responses (concise format used ~1/3 the tokens); pagination/truncation defaults (Claude Code caps tool responses at 25,000 tokens); specific actionable error messages. MCP tool schemas are deferred by default (tool search); skills must reference MCP tools fully qualified as `ServerName:tool_name` or Claude may fail to find them. ([writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents), [context window docs](https://code.claude.com/docs/en/context-window))
- **Re-audit the harness on every model upgrade.** "Every component in a harness encodes an assumption about what the model can't do on its own" — strip components that are no longer load-bearing, one at a time, and measure. ([harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps))

---

## 4. Harness engineering

- **Empirical caution on context files:** ETH Zurich/LogicStar ([arXiv 2602.11988](https://arxiv.org/abs/2602.11988)) found repo context files "do not generally improve task success rates, while increasing inference cost by over 20% on average"; LLM-generated context files *reduced* success rates; human-written ones gave ~4% improvement concentrated in undocumented repos. Recommendation: manually author, "strictly limited to indispensable operational constraints". Never /init-and-forget. ([summary](https://arxiviq.substack.com/p/evaluating-agentsmd-are-repository))
- **Instruction budget:** frontier LLMs follow roughly 150–200 instructions with reasonable consistency; Claude Code's system prompt already consumes ~50; beginning/end of context is weighted over the middle. CLAUDE.md + AGENTS.md + copilot-instructions.md + 17 skill descriptions all draw from the same pool. Every retained rule should trace to a real past failure. ([HumanLayer: writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md), [HumanLayer: skill issue](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents))
- **Verification loops are the highest-leverage feature.** Give the agent a pass/fail check (tests, build exit code, linter, link checker, diff-against-fixture) or the human becomes the loop. Escalation ladder: (1) check in the prompt → (2) `/goal` condition re-checked every turn → (3) Stop hook blocking turn-end (8-block override) → (4) fresh-context verifier subagent, because self-grading skews positive. Require evidence (command + output), not assertions. ([best practices](https://code.claude.com/docs/en/best-practices))
- **Docs repos need a synthetic check:** e.g. `make check` = markdown link check + shellcheck on scripts/ + README-index consistency, wired as a Stop hook.
- **Success is silent, failures are verbose:** check scripts should exit 0 with no output on pass and print focused errors on fail — a 4,000-line passing log floods the context window. ([HumanLayer](https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents), [Osmani: harness engineering](https://addyosmani.com/blog/agent-harness-engineering/))
- **Standard commands are the agent interface.** Spotify activates deterministic verifiers based on repo contents (pom.xml → Maven verifier), parses output so only relevant errors reach context, and runs an LLM-as-judge diff-vs-prompt scope-creep check that vetoes ~25% of sessions. Makefile-as-dev-interface (`make dev/test/lint`) is exactly this surface. ([Spotify part 3](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3))
- **Vercel eval — passive index beats skills for reference knowledge:** AGENTS.md docs index 100% pass vs 79% for a skill with invoke-instructions vs 53% baseline; the skill was never invoked in 56% of cases. Winning pattern: a pipe-delimited index compressed 80% (40KB→8KB) mapping paths to doc files. Keep skills for explicitly-triggered vertical workflows; put discovery knowledge in an always-loaded compact index. ([Vercel](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals))
- **Self-improving loop (the ratchet):** agents append discovered gotchas after each task so failures become permanent rules — "every line in a good AGENTS.md should be traceable back to a specific thing that went wrong" — but the file becomes a bloat/drift risk: keep focused, archive obsolete entries, periodic fresh starts, and human-review agent-written instructions before committing (follows from the ETH finding). ([Osmani: self-improving agents](https://addyosmani.com/blog/self-improving-agents/), [harness engineering](https://addyosmani.com/blog/agent-harness-engineering/))
- **Durable patterns across model generations:** separate generator from evaluator agents (self-grading agents "confidently praise" mediocre work), and agents exchanging work through files rather than inline conversation. ([harness design](https://www.anthropic.com/engineering/harness-design-long-running-apps))

---

## 5. GitHub Copilot & cross-tool interop

### Instruction files

- Copilot supports simultaneously: `.github/copilot-instructions.md` (repo-wide), `.github/instructions/NAME.instructions.md` (path-scoped, `applyTo` glob frontmatter required, comma-separated patterns, optional `excludeAgent`), and ONE agent file — nearest AGENTS.md takes precedence; root CLAUDE.md/GEMINI.md is only a fallback alternative. **All applicable sets are combined and sent** (personal > repository > organization is priority, not exclusion) — duplicated content reaches the model multiple times. ([GitHub: repository custom instructions](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions), [support matrix](https://docs.github.com/en/copilot/reference/custom-instructions-support))
- `excludeAgent` values are now `"code-review"` or `"cloud-agent"` (the coding agent was renamed to cloud agent; the old changelog value `coding-agent` is superseded). ([docs](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions), [changelog 2025-11-12](https://github.blog/changelog/2025-11-12-copilot-code-review-and-coding-agent-now-support-agent-specific-instructions/))
- Path-specific instructions are read by IDEs, CLI, cloud agent, and code review — but NOT by Copilot Chat on github.com. GitHub's own guidance: instructions "must be no longer than 2 pages" and "must NOT be task specific".
- Copilot code review reads repository instructions, path-scoped instructions AND skills; scope review-irrelevant files with `excludeAgent`.

### Target end-state for a dual Claude+Copilot repo

1. **AGENTS.md = canonical rules** for every Copilot surface and (via import) Claude Code.
2. **CLAUDE.md = `@AGENTS.md`** + Claude-only lines (do not delete it — Claude Code needs it).
3. **copilot-instructions.md** shrinks to Copilot-only deltas or disappears.
4. **Skills in `.claude/skills/`** — Copilot "will pick them up automatically" from `.github/skills/`, `.claude/skills/`, or `.agents/skills/`; a top-level `skills/` directory is invisible to every Copilot surface and to Claude Code's repo discovery. ([changelog 2025-12-18](https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills/), [about agent skills](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills))
5. **Agent definitions in `.claude/agents/`** — read natively by Claude Code AND by VS Code Copilot ("following the Claude sub-agents format"). A top-level `agents/` dir is discovered by neither. ([VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents), [subagents docs](https://code.claude.com/docs/en/sub-agents))
6. Copilot-only mechanisms stay in `.github/`: `instructions/*.instructions.md`, `prompts/` (IDE-only, preview), `agents/*.agent.md` (cloud agent), `workflows/copilot-setup-steps.yml`.

### Skills across Copilot surfaces

- Agent Skills are GA across the cloud agent, code review, Copilot CLI, the Copilot app, and agent mode in VS Code/JetBrains (VS Code 1.109, Jan 2026, enabled by default; slash-command invocation). ([changelog](https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills/), [VS Code 1.109](https://code.visualstudio.com/updates/v1_109))
- **Personal skill locations disagree:** VS Code reads `~/.copilot/skills/`, `~/.claude/skills/`, `~/.agents/skills/`; GitHub's Copilot CLI docs list only `~/.copilot/skills` and `~/.agents/skills` — `~/.claude/skills` is absent. A `~/.claude/skills` symlink covers Claude Code + VS Code but per GitHub's docs misses Copilot CLI; add a second symlink `~/.agents/skills`. ([VS Code agent skills](https://code.visualstudio.com/docs/agent-customization/agent-skills), [Copilot CLI skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills))
- Server-side surfaces (cloud agent, code review) never see the developer's home directory — reasonable inference from server-side execution, **not verified** as an explicit doc statement.
- Copilot CLI documents `allowed-tools` with a warning: only pre-approve shell/bash for fully trusted skills. Claude-specific frontmatter (`disable-model-invocation`, `context: fork`, `when_to_use`, `$ARGUMENTS`) degrades gracefully — Copilot ignores it.

### Other Copilot mechanisms

- **Custom agents replaced "chat modes":** rename `.chatmode.md` → `.agent.md`. Cloud-agent custom agents live in `.github/agents/NAME.agent.md`: `description` required, prompt max 30,000 chars, fields incl. `tools`, `mcp-servers`, `model`, `target` (vscode | github-copilot). ([VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents), [GitHub: create custom agents](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-custom-agents))
- **Prompt files remain public preview and IDE-only** (VS Code/Visual Studio/JetBrains — not cloud agent, CLI, or github.com). Frontmatter now uses `agent:` (ask/agent/plan/custom-agent name), not `mode:`. Skills are the more portable choice for reusable workflows. ([your first prompt file](https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file), [VS Code prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files))
- **copilot-setup-steps.yml:** must be on the default branch; single job that MUST be named `copilot-setup-steps`; only `steps`, `permissions`, `runs-on`, `services`, `snapshot`, `timeout-minutes` (≤59) are honored; Ubuntu x64 and Windows 64-bit runners supported (macOS not). "Ubuntu x64 is the default" — not verified. ([customize agent environment](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-environment))
- **VS Code scaffolding commands:** `/init` (generates copilot-instructions.md), `/create-instructions`, `/create-prompt`, `/create-skill`, `/create-agent`. `/create-hook` — not verified. Writing criteria: short and self-contained, include the reasoning behind rules, show preferred and avoided patterns with concrete examples. ([customize AI guide](https://code.visualstudio.com/docs/agents/guides/customize-copilot-guide), [VS Code custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions))

---

## 6. Orchestration & multi-agent

- **Multi-agent is a ~15x token bet.** Agents ≈4x chat tokens; multi-agent ≈15x. Worth it only for high-value, heavily parallelizable work or information exceeding one context window; "most coding tasks involve fewer truly parallelizable tasks than research". Cognition's counterpoint: parallel agents make conflicting implicit decisions without shared context — prefer a single-threaded agent + context compression for most coding. ([Anthropic multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system), [agent teams docs](https://code.claude.com/docs/en/agent-teams), [Cognition: Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents))
- **Four-part delegation contract:** every subagent prompt needs an objective, an output format, guidance on tools/sources, and clear task boundaries. Delegation prompts must be self-contained — the subagent never sees conversation history; Explore/Plan don't even see CLAUDE.md, so repo rules must be restated. ([multi-agent post](https://www.anthropic.com/engineering/multi-agent-research-system), [subagents docs](https://code.claude.com/docs/en/sub-agents))
- **Numeric effort scaling:** simple fact-finding = 1 agent / 3–10 tool calls; comparisons = 2–4 agents / 10–15 calls each; complex work = 10+ agents with divided responsibilities. Teams: start with 3–5 teammates, 5–6 self-contained tasks each; "Three focused teammates often outperform five scattered ones." ([multi-agent post](https://www.anthropic.com/engineering/multi-agent-research-system), [agent teams](https://code.claude.com/docs/en/agent-teams))
- **Parallel review pattern:** one distinct lens per reviewer (security / performance / test coverage), fresh contexts, single synthesis+dedupe step. Fresh context avoids bias toward code the model just wrote — the implementing session never grades its own work. ([agent teams](https://code.claude.com/docs/en/agent-teams), [best practices](https://code.claude.com/docs/en/best-practices), [workflows](https://code.claude.com/docs/en/workflows))
- **Adversarial verification kills false positives:** "adversarially verify each finding before reporting it"; reviewer dispatches a verifier per finding (nested subagents since v2.1.172, depth ≤5); report three-way status confirmed / refuted / unverified; maintain an explicit noise-exclusion list (the security-review action excludes DoS, rate limiting, generic input validation without proven impact, open redirects by default). The agent that found an issue must not confirm it. ([workflows](https://code.claude.com/docs/en/workflows), [subagents](https://code.claude.com/docs/en/sub-agents), [claude-code-security-review](https://github.com/anthropics/claude-code-security-review))
- **Constrain reviewers or they manufacture work:** "A reviewer prompted to find gaps will usually report some, even when the work is sound." Scope the prompt: what to check, criteria, what counts as a finding — "Report gaps, not style preferences"; correctness/requirements only, rest optional. ([best practices](https://code.claude.com/docs/en/best-practices))
- **Competing-hypotheses debugging:** for 2+ plausible root causes, spawn one investigator per hypothesis instructed to disprove the others; the surviving theory wins (counteracts anchoring bias). Agent teams remain experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). ([agent teams](https://code.claude.com/docs/en/agent-teams))
- **Explore → Plan → Implement → Commit,** with skip heuristic: "If you could describe the diff in one sentence, skip the plan." Plan is human-edited (Ctrl+G); larger features: spec-interview → SPEC.md → execute in a **fresh session**. ACE-FCA targets: 40–60% context utilization; humans review ~200 lines of plan instead of thousands of diff lines; gates on research and plan because "a bad line of a plan could lead to hundreds of bad lines of code". ([best practices](https://code.claude.com/docs/en/best-practices), [HumanLayer ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md))
- **Long-running autonomous work:** initializer artifacts (init.sh, feature_list.json with pass flags, progress notes, initial commit) + one feature per session + commit per session + re-orientation ritual (pwd, git log, progress files, run init.sh and a smoke test) + testable done-conditions written before execution. Prevents premature victory declarations and undocumented broken state. ([long-running harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), [Osmani: long-running agents](https://addyosmani.com/blog/long-running-agents/))
- **Resume, don't redo:** subagents resume with full history via SendMessage (transcripts persist ~30 days); sessions via `--continue` / `--resume` / `--from-pr`; every prompt checkpoints for `/rewind`. Exception: Explore/Plan return no agent ID — use general-purpose/custom agents when continuation might be needed. ([subagents](https://code.claude.com/docs/en/sub-agents), [common workflows](https://code.claude.com/docs/en/common-workflows))
- **Choose the primitive by who holds the plan:** subagents = spawned workers, results land in caller's context; skills = inline instructions; agent teams = long-running peers with shared task list (experimental); dynamic workflows = a script the runtime executes (loops/state in variables, up to 16 concurrent / 1,000 agents per run, saved in `.claude/workflows/`). Workflows/teams are Claude-Code-only — Copilot consumers won't have them. ([workflows](https://code.claude.com/docs/en/workflows), [agent teams](https://code.claude.com/docs/en/agent-teams))
- **Skills as orchestration units:** `context: fork` + `agent:` runs a skill body as a subagent prompt (agent: Explore for cheap read-only research) — only for skills with explicit instructions; passive guideline skills forked this way return nothing useful. Inversely, a subagent's `skills:` field preloads full skill content — how a reviewer agent gets conventions without discovery. `disable-model-invocation: true` skills can be neither auto-triggered nor preloaded. ([skills docs](https://code.claude.com/docs/en/skills), [subagents](https://code.claude.com/docs/en/sub-agents))
- **Parallelize reads, serialize/isolate writes:** "Two teammates editing the same file leads to overwrites" — partition file ownership pre-dispatch; start multi-agent adoption with read-only work. Isolation mechanisms: `claude --worktree <name>`, `isolation: worktree` frontmatter, per-file isolated copies in workflows. ([agent teams](https://code.claude.com/docs/en/agent-teams), [subagents](https://code.claude.com/docs/en/sub-agents), [common workflows](https://code.claude.com/docs/en/common-workflows), [Cognition](https://cognition.com/blog/dont-build-multi-agents))

---

## Sources

### Claude Code
- https://code.claude.com/docs/en/best-practices
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/features-overview
- https://code.claude.com/docs/en/context-window
- https://code.claude.com/docs/en/sandboxing
- https://code.claude.com/docs/en/devcontainer
- https://code.claude.com/docs/en/common-workflows
- https://www.anthropic.com/engineering/claude-code-best-practices (308 → best-practices doc)
- https://github.com/anthropics/claude-code/tree/main/.devcontainer

### Prompt engineering
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5
- https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_prompting_guide
- https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide
- https://www.keepmyprompts.com/en/blog/claude-fable-5-cut-prompt-scaffolding-2026

### Context engineering
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://agentskills.io/specification
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://www.anthropic.com/engineering/writing-tools-for-agents
- https://www.anthropic.com/engineering/harness-design-long-running-apps
- https://www.anthropic.com/engineering/managed-agents

### Harness engineering
- https://agents.md/
- https://arxiv.org/abs/2602.11988
- https://arxiviq.substack.com/p/evaluating-agentsmd-are-repository
- https://www.humanlayer.dev/blog/writing-a-good-claude-md
- https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents
- https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3
- https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals
- https://addyosmani.com/blog/self-improving-agents/
- https://addyosmani.com/blog/agent-harness-engineering/

### Copilot
- https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions
- https://docs.github.com/en/copilot/reference/custom-instructions-support
- https://docs.github.com/en/copilot/concepts/agents/about-agent-skills
- https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-environment
- https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-custom-agents
- https://docs.github.com/en/copilot/tutorials/customization-library/prompt-files/your-first-prompt-file
- https://github.blog/changelog/2025-08-28-copilot-coding-agent-now-supports-agents-md-custom-instructions/
- https://github.blog/changelog/2025-11-12-copilot-code-review-and-coding-agent-now-support-agent-specific-instructions/
- https://github.blog/changelog/2025-12-18-github-copilot-now-supports-agent-skills/
- https://code.visualstudio.com/docs/agent-customization/custom-instructions
- https://code.visualstudio.com/docs/agent-customization/agent-skills
- https://code.visualstudio.com/docs/agent-customization/custom-agents
- https://code.visualstudio.com/docs/agent-customization/prompt-files
- https://code.visualstudio.com/docs/agents/guides/customize-copilot-guide
- https://code.visualstudio.com/updates/v1_109

### Orchestration
- https://www.anthropic.com/engineering/multi-agent-research-system
- https://code.claude.com/docs/en/agent-teams
- https://code.claude.com/docs/en/workflows
- https://cognition.com/blog/dont-build-multi-agents
- https://github.com/anthropics/claude-code-security-review
- https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md
- https://addyosmani.com/blog/long-running-agents/
