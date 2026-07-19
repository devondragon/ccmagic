# Design: per-step subagents + per-step models for `auto-ticket`

**Status:** implemented in 3.2.0 — historical design record
**Target version:** 3.2.0 (additive feature)
**Branch:** `feature/auto-ticket-per-step-subagents`

## Problem

`/ccmagic:auto-ticket` (shipped in 3.1.0) drives the ticket lifecycle by invoking each step **inline via the Skill tool** in one continuous context: `work-ticket → review-ticket → pr-feedback (looped) → finish-ticket`, with `push` and `validate` mixed in. Because everything runs in one context, a long unattended run accumulates the full implementation diff, review output, feedback loop, and CI-poll results in a single window — which leans on summarization and is heaviest exactly on the unattended/headless (Cyrus) path this feature targets.

Two upgrades address that:

1. **Per-step subagents** — run each lifecycle step in its own isolated subagent context so the orchestrator stays lean and each step gets a clean slate. Configurable, defaulting to forked.
2. **Per-step models** — run the best-suited model per step (strong models where judgment matters, light models for mechanical steps), configurable per repo.

## Decisions (locked)

- **Fork config:** dropped — `auto-ticket` always runs each step in its own forked subagent. (An earlier design had a `fork_steps` toggle with an inline mode, but a forked orchestrator can't invoke the `context: fork` skills `work`/`review`/`validate` reach, so the inline mode was unachievable.)
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

- **Skill-frontmatter model strategy (designs the clobber risk out at the source):** rather than rely solely on the preload-not-invoke trick, adjust the lifecycle skills' own `model:` so they never *disagree* with the step-agent's model:
  - `work-ticket`, `review-ticket` → `model: inherit` (no pinned model to fight — inherits the step-agent's `opus` in autonomous, and the user's session model interactively).
  - `push` → `model: haiku` (always trivial; cheap everywhere, interactive included).
  - `pr-feedback`, `finish-ticket`, `validate` → keep `sonnet` (they already match their step-agent's `sonnet`).

  After this, every step's skill model either *inherits* (nothing to clobber) or *matches* the step-agent — zero model conflicts — so per-step models are correct by construction and the preload trick becomes belt-and-suspenders. Tradeoff (accepted): this changes the interactive default for `work`/`review` (now scale to the session model) and `push` (now `haiku`); a `haiku` session would get a weaker interactive `work`/`review`, which is acceptable.

## Key mechanics (from Claude Code docs research)

These three facts constrain the design:

1. **An inline skill cannot spawn subagents.** Only a skill running *as* a subagent may use the `Task` tool. → For the orchestrator to fan work out to per-step subagents, **`auto-ticket` must itself run forked** (`context: fork`). It already declares `Task(*)` in `allowed-tools`; it just can't use it until forked.
2. **Per-step model is set on a per-step agent definition** (`agents/*.md` with a `model:` field). Subagent model resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env → per-invocation `Task` param → agent frontmatter `model:` → session model. → Agent frontmatter gives a **deterministic default**; a config value can be passed as a best-effort per-invocation override.
3. **A forked skill cannot invoke another forked skill.** The existing lifecycle skills transitively call `context: fork` skills (`review`, `validate`). → Per-step agents **preload** the skills they need (agent `skills:` frontmatter injects skill *content* without invoking it) and run that procedure inline on their own model. This flattens the fork chain into one isolated, correctly-modeled context.

## Architecture

```
/ccmagic:auto-ticket   (context: fork  ← now runs as a subagent)
    │  Step 0: resolve tracker/ticket/config, read model_<step>,
    │          build the grounding block (unchanged contract §2)
    │
    └─ spawn each step as a child subagent (Task):
          auto-work      (model: opus)    preloads work-ticket + debug
          auto-review    (model: opus)    preloads review-ticket + review
          auto-feedback  (model: sonnet)  preloads pr-feedback + push
          auto-validate  (model: sonnet)  preloads validate
          auto-finish    (model: sonnet)  preloads finish-ticket
          auto-push      (model: haiku)   preloads push
             └ each child runs its step in autonomous mode and returns ONLY
               its handshake block; the orchestrator parses the last block.
```

Each per-step agent is a **thin wrapper**: *"You are running the {step} step of an autonomous ticket run. Follow the preloaded {skill} procedure in autonomous mode with the grounding block below, then end with the handshake block."* The lifecycle skills and their autonomous sections are **reused unchanged in logic** (only three skills' `model:` line is tuned — see the model strategy) — the agents only add model selection + context isolation.

> `push` shows up twice on purpose: `auto-feedback` **preloads** it because `pr-feedback` commits/pushes its own fixes internally (that push runs inline within the feedback step's model), while `auto-push` is the dedicated agent the orchestrator spawns for its *own* pushes (the Step 3 review-fix loop and Step 4b validate-fix). The `push → haiku` mapping refers to the dedicated `auto-push` step.

### Data flow across the boundary

- **In:** the orchestrator passes the grounding block (contract §2) as part of the `Task` prompt when spawning the child. Config overrides (`model_<step>`) are passed as the per-invocation model param (best-effort).
- **Out:** the child's final response is returned to the orchestrator as text; the orchestrator parses the **last** handshake block (contract §3) exactly as it does for inline steps today. A child that returns no handshake is treated as `needs-human` (contract §3, unchanged).

### Orchestrator step-execution mode

`auto-ticket` gains a "step execution" helper concept: `run_step(step, grounding)` = *spawn the step's agent via `Task` and parse the returned handshake.* Every existing orchestration decision (route-and-stop, the pr-feedback loop bounds, review-fix loop, CI polling) is unchanged — only *how a step is executed* changes (from inline `Skill` invocation in 3.1.0 to a forked per-step subagent in 3.2.0).

## Config surface (additive, all optional)

```yaml
# .claude/ccmagic.local.md
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

## CI wait mechanism (added after field-run B, 2026-07)

The one long-latency step in the run — Step 4c's "wait for CI" — was originally specced as a 60s poll loop, which is not executable: the orchestrator runs as a forked subagent whose toolset (`Read, Edit, Bash(git/gh), Glob, Grep, Task, TodoWrite, Skill`) has no wait primitive, and foreground sleep is blocked in the harness. In field-run B the fork returned control and the run silently stalled — the "third outcome" contract §6 promises never happens.

The mechanism is now a **bounded blocking watch**: `gh pr checks {PR} --watch --interval {ci_poll_interval_seconds}` invoked as a single Bash call at the maximum tool timeout (600000 ms), re-invoked while elapsed time (tracked via `date +%s`) is under `ci_timeout_minutes`, then route-and-stop on timeout. `--watch` blocks inside one Bash call, which *is* executable in a forked subagent, portable to headless/Cyrus deployments (needs only `gh`), and stays inside the already-allowed `Bash(gh:*)` surface. A no-checks guard (re-check up to 3×, then treat as "no CI configured") covers the check-registration race just after a push; finish-ticket's merge gate re-verifies `statusCheckRollup` as the backstop.

The wait deliberately stays in Step 4c (not finish-ticket): the feedback loop's new-bot-review detection (high-water-mark `H`) needs CI and reviews to have settled *inside* the loop.

## Risks to validate during implementation

1. **Skill-frontmatter model clobber — now designed out (was highest priority):** originally the concern was that an invoked lifecycle skill's own `model: sonnet` would override the step-agent's chosen model. The skill-frontmatter model strategy above removes the disagreement at the source (skills `inherit` or already match the step-agent), so no step has a model to clobber. The preload-not-invoke approach remains as belt-and-suspenders. Nothing model-related needs a live smoke test now; the end-to-end test only confirms the fork + handshake plumbing.
2. **Config-driven per-step override is best-effort** (the per-invocation `Task` model param is chosen by model reasoning, not a hard syntax). Treat **agent-frontmatter defaults as authoritative**; `model_<step>` overrides are a convenience layer. Document this expectation.
3. **Nesting depth:** orchestrator (fork, depth 1) → step agent (Task, depth 2) → step's own Task fan-out (depth 3) stays within the depth-5 limit. Confirm no step pushes past it.

## Non-goals (v1)

- No per-step *fork* granularity (global `fork_steps` only).
- No backlog triage/selector (separate future skill; this design just stays compatible with one).
- No change to any interactive *logic*. The only frontmatter change is the `model:` line on three skills (`work-ticket`/`review-ticket` → `inherit`, `push` → `haiku`), which does affect their interactive default model. This upgrade is purely additive and lives in the orchestrator + new agent wrappers.

## Resolved — fork_steps dropped

`auto-ticket` is unconditionally `context: fork`, so it runs as a subagent — and a subagent cannot invoke a `context: fork` skill via `Skill`. Several steps reach fork skills: `validate` *is* `context: fork`; `review-ticket` invokes `review` (fork); `work-ticket` invokes `review`/`analyze-impact` (fork). That meant the originally-designed `fork_steps: false` inline path could never purely inline those steps, and would not have reproduced the pre-3.2.0 flow regardless (the orchestrator is forked either way).

This was resolved by dropping `fork_steps` entirely rather than picking between the two options considered at the time ("inline where the skill has no fork dependency" vs. "always fork per step") — `auto-ticket` now always forks each step to its per-step agent. This also matches the feature's actual purpose: per-step isolation and per-step models are the whole point, so an inline mode was never something worth preserving.

## Backward compatibility

- `fork_steps` was dropped — see *Resolved — fork_steps dropped* above. There is no inline mode; every step always runs forked to its per-step agent, and the orchestrator itself always runs forked.
- All new config keys default to the shipped values; an untouched `.claude/ccmagic.local.md` gets the Balanced/forked defaults automatically.
- The lifecycle skills' logic, their autonomous sections, and the handshake contract are unchanged; only three skills' `model:` line changed.
