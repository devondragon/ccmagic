# Design: per-step subagents + per-step models for `auto-ticket`

**Status:** approved design, pre-implementation
**Target version:** 3.2.0 (additive feature)
**Branch:** `feature/auto-ticket-per-step-subagents`

## Problem

`/ccmagic:auto-ticket` (shipped in 3.1.0) drives the ticket lifecycle by invoking each step **inline via the Skill tool** in one continuous context: `work-ticket → review-ticket → pr-feedback (looped) → finish-ticket`, with `push` and `validate` mixed in. Because everything runs in one context, a long unattended run accumulates the full implementation diff, review output, feedback loop, and CI-poll results in a single window — which leans on summarization and is heaviest exactly on the unattended/headless (Cyrus) path this feature targets.

Two upgrades address that:

1. **Per-step subagents** — run each lifecycle step in its own isolated subagent context so the orchestrator stays lean and each step gets a clean slate. Configurable, defaulting to forked.
2. **Per-step models** — run the best-suited model per step (strong models where judgment matters, light models for mechanical steps), configurable per repo.

## Decisions (locked)

- **Fork config:** a single global toggle `fork_steps` (default `true`). `false` restores today's fully-inline behavior. No per-step fork granularity in v1 (YAGNI — can add later).
- **Model mapping (Balanced, default):**

  | Step | Default model |
  |------|---------------|
  | work-ticket | `opus` |
  | review-ticket | `opus` |
  | pr-feedback | `sonnet` |
  | finish-ticket | `sonnet` |
  | validate | `sonnet` |
  | push | `haiku` |

  All overridable per repo. Strong models where a wrong call is expensive (implement, review); light models for mechanical steps (push).

## Key mechanics (from Claude Code docs research)

These three facts constrain the design:

1. **An inline skill cannot spawn subagents.** Only a skill running *as* a subagent may use the `Task` tool. → For the orchestrator to fan work out to per-step subagents, **`auto-ticket` must itself run forked** (`context: fork`). It already declares `Task(*)` in `allowed-tools`; it just can't use it until forked.
2. **Per-step model is set on a per-step agent definition** (`agents/*.md` with a `model:` field). Subagent model resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env → per-invocation `Task` param → agent frontmatter `model:` → session model. → Agent frontmatter gives a **deterministic default**; a config value can be passed as a best-effort per-invocation override.
3. **A forked skill cannot invoke another forked skill.** The existing lifecycle skills transitively call `context: fork` skills (`review`, `validate`). → Per-step agents **preload** the skills they need (agent `skills:` frontmatter injects skill *content* without invoking it) and run that procedure inline on their own model. This flattens the fork chain into one isolated, correctly-modeled context.

## Architecture

```
/ccmagic:auto-ticket   (context: fork  ← now runs as a subagent)
    │  Step 0: resolve tracker/ticket/config, read fork_steps + model_<step>,
    │          build the grounding block (unchanged contract §2)
    │
    ├─ fork_steps: true  (default) → spawn each step as a child subagent (Task):
    │     auto-work      (model: opus)    preloads work-ticket
    │     auto-review    (model: opus)    preloads review-ticket + review
    │     auto-feedback  (model: sonnet)  preloads pr-feedback + push
    │     auto-validate  (model: sonnet)  preloads validate
    │     auto-finish    (model: sonnet)  preloads finish-ticket
    │     auto-push      (model: haiku)   preloads push
    │        └ each child runs its step in autonomous mode and returns ONLY
    │          its handshake block; the orchestrator parses the last block.
    │
    └─ fork_steps: false → run the steps inline via the Skill tool inside the
          forked orchestrator's own context (today's flow, one level down).
```

Each per-step agent is a **thin wrapper**: *"You are running the {step} step of an autonomous ticket run. Follow the preloaded {skill} procedure in autonomous mode with the grounding block below, then end with the handshake block."* The five lifecycle skills and their autonomous sections are **reused unchanged** — the agents only add model selection + context isolation.

> `push` shows up twice on purpose: `auto-feedback` **preloads** it because `pr-feedback` commits/pushes its own fixes internally (that push runs inline within the feedback step's model), while `auto-push` is the dedicated agent the orchestrator spawns for its *own* pushes (the Step 3 review-fix loop and Step 4b validate-fix). The `push → haiku` mapping refers to the dedicated `auto-push` step.

### Data flow across the boundary

- **In:** the orchestrator passes the grounding block (contract §2) as part of the `Task` prompt when spawning the child. Config overrides (`model_<step>`) are passed as the per-invocation model param (best-effort).
- **Out:** the child's final response is returned to the orchestrator as text; the orchestrator parses the **last** handshake block (contract §3) exactly as it does for inline steps today. A child that returns no handshake is treated as `needs-human` (contract §3, unchanged).

### Orchestrator step-execution mode

`auto-ticket` gains a "step execution" helper concept: `run_step(step, grounding)` = *if `fork_steps` → spawn the step's agent via `Task` and parse the returned handshake; else → invoke the step's skill inline via `Skill` and parse its handshake.* Every existing orchestration decision (route-and-stop, the pr-feedback loop bounds, review-fix loop, CI polling) is unchanged — only *how a step is executed* changes.

## Config surface (additive, all optional)

```yaml
# .claude/ccmagic.local.md
fork_steps: true          # default — per-step subagents; false = inline (today)

# Per-step model overrides (defaults live in the agent files):
model_work_ticket:   opus
model_review_ticket: opus
model_pr_feedback:   sonnet
model_finish_ticket: sonnet
model_validate:      sonnet
model_push:          haiku
```

Resolution for these keys follows the existing project → user → built-in precedence (contract §5). Defaults = the Balanced mapping, baked into the agent frontmatter; the `model_*` keys override best-effort at spawn time.

## Files

**New:**
- `agents/auto-work.md`, `agents/auto-review.md`, `agents/auto-feedback.md`, `agents/auto-validate.md`, `agents/auto-finish.md`, `agents/auto-push.md` — thin per-step wrapper agents (frontmatter: `name`, `description`, `model`, `skills`, `tools`; body: run the preloaded step in autonomous mode + emit handshake).

**Changed:**
- `skills/auto-ticket/SKILL.md` — add `context: fork`; add a "Step execution mode" section (fork-via-Task vs inline) and the `run_step` helper concept; document config keys `fork_steps` + `model_<step>`; note the handshake now returns across the subagent boundary (format unchanged).
- `skills/auto-ticket/autonomous-contract.md` — extend §5 config table with `fork_steps` + `model_<step>`; add a short "step execution" note.
- `docs/ccmagic.local.md.example` — new keys + explainer.
- `README.md` — Autonomous-mode section: note per-step subagents + per-step models and how to configure.
- `CHANGELOG.md` — `[3.2.0]` entry.
- `.claude-plugin/plugin.json` + `marketplace.json` — version → 3.2.0.

## Behavior changes

- `auto-ticket` becoming `context: fork` means the whole run executes in an isolated subagent; the main session receives the **returned run summary** rather than fully inline narration (progress still shows in the task pane). This is more aligned with the "keep context lean" goal, and `auto-ticket` is new (3.1.0) so there is no back-compat concern.
- Because a subagent cannot invoke a `context: fork` skill, a **future backlog selector** must invoke `auto-ticket` from the main session, not from inside its own fork. Noted so we don't design that into a corner.
- Inside a step subagent, any transitively-invoked `context: fork` skill (e.g. work-ticket → analyze-impact, review-ticket → review) runs **inline** within that step's isolated context rather than forking again. Preloading the needed skills on the agent makes this clean.
- To avoid double-review, the orchestrated **work** step should defer full code review to the orchestrator's dedicated **review** step (it already runs `review-ticket` in Step 3); the work step keeps only its lightweight self-check.

## Risks to validate during implementation

1. **Skill-frontmatter model clobber (highest priority to smoke-test):** an invoked lifecycle skill declares its own `model:` (e.g. `work-ticket` → `sonnet`). The **preload-not-invoke** approach is specifically chosen to avoid the skill re-pinning the model, but this must be verified: spawn `auto-work` (opus), confirm the work actually runs on opus and isn't dropped to the skill's frontmatter model. If preload still clobbers, fall back to agent-frontmatter model as the source of truth and drop the invoke path.
2. **Config-driven per-step override is best-effort** (the per-invocation `Task` model param is chosen by model reasoning, not a hard syntax). Treat **agent-frontmatter defaults as authoritative**; `model_<step>` overrides are a convenience layer. Document this expectation.
3. **Nesting depth:** orchestrator (fork, depth 1) → step agent (Task, depth 2) → step's own Task fan-out (depth 3) stays within the depth-5 limit. Confirm no step pushes past it.

## Non-goals (v1)

- No per-step *fork* granularity (global `fork_steps` only).
- No backlog triage/selector (separate future skill; this design just stays compatible with one).
- No change to any interactive path or to the five lifecycle skills' own frontmatter/behavior. This upgrade is purely additive and lives in the orchestrator + new agent wrappers.

## Backward compatibility

- `fork_steps: false` reproduces 3.1.0 behavior (inline steps), so anyone who prefers the current flow keeps it with one line.
- All new config keys default to the shipped values; an untouched `.claude/ccmagic.local.md` gets the Balanced/forked defaults automatically.
- The five lifecycle skills, their autonomous sections, and the handshake contract are unchanged.
