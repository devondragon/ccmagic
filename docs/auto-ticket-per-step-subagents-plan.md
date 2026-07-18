# auto-ticket Per-Step Subagents + Per-Step Models — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/ccmagic:auto-ticket` run each lifecycle step in its own forked subagent (configurable, default on) on a best-fit per-step model, reusing the five lifecycle skills unchanged.

**Architecture:** `auto-ticket` becomes `context: fork` so it can spawn subagents. Six thin per-step wrapper agents in `agents/` each **preload** their lifecycle skill and run it in autonomous mode on their own `model:`, returning only the status handshake. A `fork_steps` toggle chooses per-step subagents (default) vs today's inline flow; `model_<step>` keys override the defaults.

**Tech Stack:** Claude Code plugin — Markdown SKILL/agent files with YAML frontmatter, `Task`/`Skill` tools, bash verification. No compiled code, no unit-test harness; "tests" are structural validators + a local plugin load-test + one interactive end-to-end smoke test.

## Global Constraints

- **Additive & opt-in:** no interactive *logic/behavior* of the five lifecycle skills changes. The ONLY frontmatter change permitted is the per-skill `model:` line (see the model strategy below): `work-ticket`/`review-ticket` → `inherit`, `push` → `haiku`; `pr-feedback`/`finish-ticket`/`validate` stay `sonnet`. All other new behavior is gated behind `fork_steps` / `model_<step>` / the autonomous signal.
- **Model strategy (removes clobber at the source):** skills either `inherit` (no pinned model to fight the step-agent) or already match their step-agent's model, so per-step models are correct by construction. The step-agents remain the authoritative model source; the preload-not-invoke approach is belt-and-suspenders.
- **Handshake contract unchanged:** steps still end with the `status: clean | fixable-findings | needs-human | done` fenced block (contract §3); it now returns across the subagent boundary. A missing handshake = `needs-human`.
- **Config precedence:** new keys resolve project `.claude/ccmagic.local.md` → user `~/.claude/ccmagic.local.md` → built-in default (contract §5).
- **Balanced model mapping (defaults):** work-ticket→`opus`, review-ticket→`opus`, pr-feedback→`sonnet`, finish-ticket→`sonnet`, validate→`sonnet`, push→`haiku`.
- **Model aliases only** (`opus`/`sonnet`/`haiku`/`inherit`) — never pin full model IDs, for portability.
- **Model safety rule:** per-step agents run their step by following the **preloaded** skill content directly; they do **not** carry the `Skill` tool for the primary step (re-invoking a skill would re-pin that skill's own `model:` frontmatter and defeat per-step model selection).
- **Version target:** 3.2.0. Branch: `feature/auto-ticket-per-step-subagents`. Spec: `docs/auto-ticket-per-step-subagents-design.md`.

---

### Task 1: Fork mechanic proof-of-concept on the `push` step

De-risk the linchpin (model-per-subagent + handshake return) on the cheapest step before building the rest. Delivers a working forked `push` step; other steps stay inline until Task 3.

**Files:**
- Create: `agents/auto-push.md`
- Modify: `skills/auto-ticket/SKILL.md` (add `context: fork`; add a minimal "Step execution mode" section that routes only `push` through its agent when `fork_steps` is true)

**Interfaces:**
- Produces: agent `auto-push` (spawned via `Task` by name), model `haiku`, preloads `ccmagic:push`, returns the push handshake block.
- Consumes: the grounding block (contract §2), passed as the `Task` prompt.

- [ ] **Step 1: Create `agents/auto-push.md`**

```markdown
---
name: auto-push
description: Autonomous-run PUSH step. Commits and pushes the working tree in autonomous mode, then returns the ccmagic status handshake. Spawned by /ccmagic:auto-ticket when fork_steps is true. Not for direct human use.
model: haiku
skills:
  - ccmagic:push
tools: Read, Bash, Glob, Grep, Write
---

You are running the **push** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `push` skill procedure in autonomous mode**, using the grounding block in your task prompt below (it carries `autonomous: true`, the tracker/ticket/PR context, and the needs-human config). Do only the push: commit the working tree in logical groups and push. Never touch review, feedback, or merge.

Because you were invoked with an autonomous grounding block from `auto-ticket`, you are **orchestrated** — on a `needs-human` outcome, do NOT park the ticket yourself; emit the handshake and stop so the orchestrator routes it.

Follow the push skill's procedure directly using your Bash/git tools. Do not re-invoke `/ccmagic:push` as a skill.

Return **only** the push autonomous handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: <one line — commits pushed on done; the blocking file/conflict on needs-human>
follow_ups: []
```

Grounding block (your task prompt):
```

- [ ] **Step 2: Verify the agent frontmatter parses and has the required fields**

Run:
```bash
cd /Users/devon/git/ccmagic
python3 - <<'PY'
import yaml, pathlib
raw = pathlib.Path("agents/auto-push.md").read_text().split("---")[1]
fm = yaml.safe_load(raw)
assert fm["name"] == "auto-push", fm
assert fm["model"] == "haiku", fm
assert fm["skills"] == ["ccmagic:push"], fm
assert "Skill" not in str(fm.get("tools","")), "push agent must not carry the Skill tool"
print("auto-push frontmatter OK:", fm)
PY
```
Expected: `auto-push frontmatter OK: {...}` and no assertion error.

- [ ] **Step 3: Add `context: fork` to `auto-ticket` frontmatter**

Modify `skills/auto-ticket/SKILL.md` frontmatter — add one line after `model: sonnet`:
```yaml
context: fork
```

- [ ] **Step 4: Add the minimal "Step execution mode" section to `auto-ticket`**

Insert this section immediately after the `## The contract` section in `skills/auto-ticket/SKILL.md`:

```markdown
## Step execution mode

`auto-ticket` runs **forked** (`context: fork`), so it executes as a subagent and can spawn a child subagent per step. How each step below runs is decided by `fork_steps` (config, default `true`):

- **`fork_steps: true` (default)** — run the step by spawning its per-step agent via the `Task` tool, passing the grounding block as the task prompt, and parsing the **last** handshake block from the child's returned text. Each per-step agent runs on its own model (see the registry) and in an isolated context.
- **`fork_steps: false`** — run the step inline via the `Skill` tool inside this orchestrator's own context (the 3.1.0 behavior, one level down).

Call this `run_step(step, grounding)`. In this iteration only the **push** step routes through `run_step`: run the `/ccmagic:push` commit-and-push call sites (in the Step 3 review-fix loop and Step 4b validate-fix) via `run_step` — forked to the `auto-push` agent when `fork_steps` is true, inline via `Skill` otherwise. All other steps continue to run inline as in 3.1.0; a later change routes them too. Nothing else about the flow (route-and-stop, loops, bounds) changes.

### Per-step agent registry

| Step | Agent | Default model | Config override |
|------|-------|---------------|-----------------|
| work-ticket | `auto-work` | `opus` | `model_work_ticket` |
| review-ticket | `auto-review` | `opus` | `model_review_ticket` |
| pr-feedback | `auto-feedback` | `sonnet` | `model_pr_feedback` |
| validate | `auto-validate` | `sonnet` | `model_validate` |
| finish-ticket | `auto-finish` | `sonnet` | `model_finish_ticket` |
| push | `auto-push` | `haiku` | `model_push` |

Model resolution per step: the agent's frontmatter `model:` is the authoritative default; if a `model_<step>` config value is set, pass it as the `Task` per-invocation model override (best-effort). Only `push` is wired in this iteration; the rest are added in a later change.
```

- [ ] **Step 5: Verify the skill still has valid frontmatter and balanced fences**

Run:
```bash
cd /Users/devon/git/ccmagic
python3 -c "import yaml,pathlib; print('fm ok:', yaml.safe_load(pathlib.Path('skills/auto-ticket/SKILL.md').read_text().split('---')[1])['context'])"
c=$(grep -c '```' skills/auto-ticket/SKILL.md); echo "fences: $c $([ $((c%2)) -eq 0 ] && echo OK || echo ODD)"
```
Expected: `fm ok: fork` and `fences: <even> OK`.

- [ ] **Step 6: Interactive smoke test — the linchpin**

This is the decision gate; it needs a real run in the Claude Code UI (model identity per subagent is not introspectable from inside a skill).

In a repo wired to a tracker (e.g. the MagicMenu repo with the Linear MCP), with `fork_steps: true` in `.claude/ccmagic.local.md`, drive a run that reaches the push step and confirm in the **task pane**:
1. A child subagent (`auto-push`) is spawned for the push step (not run inline).
2. Its model shows as **haiku** — i.e. `push`'s own `model:` frontmatter did **not** clobber it (validates spec risk #1).
3. The child returns a `status: …` handshake block the orchestrator parses.
4. Set `fork_steps: false` and confirm push then runs **inline** (no child spawned).

**Gate:** If the model is clobbered to `push`'s frontmatter value, apply spec risk-#1 fallback before Task 2: keep the agent-frontmatter model authoritative and confirm the agent is following the *preloaded* procedure (never invoking `/ccmagic:push` via `Skill`). Do not proceed to Task 2 until 1–4 hold.

- [ ] **Step 7: Commit**

```bash
cd /Users/devon/git/ccmagic
git add agents/auto-push.md skills/auto-ticket/SKILL.md
git commit -m "feat(auto-ticket): fork the push step via per-step agent (PoC)"
```

---

### Task 1.5: Adjust lifecycle-skill model frontmatter

Removes the model-clobber risk at the source (see design "Skill-frontmatter model strategy"). Frontmatter `model:` line only — no logic changes.

**Files:**
- Modify: `skills/work-ticket/SKILL.md`, `skills/review-ticket/SKILL.md`, `skills/push/SKILL.md`

- [ ] **Step 1:** In `skills/work-ticket/SKILL.md` frontmatter, change `model: sonnet` → `model: inherit`.
- [ ] **Step 2:** In `skills/review-ticket/SKILL.md` frontmatter, change `model: sonnet` → `model: inherit`.
- [ ] **Step 3:** In `skills/push/SKILL.md` frontmatter, change `model: sonnet` → `model: haiku`.
- [ ] **Step 4:** Leave `pr-feedback`, `finish-ticket`, `validate` at `sonnet` (they already match their step-agent — do not touch).
- [ ] **Step 5: Verify**

```bash
cd /Users/devon/git/ccmagic
for s in work-ticket review-ticket push pr-feedback finish-ticket validate; do
  echo "$s: $(grep -m1 '^model:' skills/$s/SKILL.md)"
done
```
Expected: `work-ticket`/`review-ticket` = `inherit`, `push` = `haiku`, the other three = `sonnet`.

- [ ] **Step 6: Commit**

```bash
cd /Users/devon/git/ccmagic
git add skills/work-ticket/SKILL.md skills/review-ticket/SKILL.md skills/push/SKILL.md
git commit -m "feat(skills): tune lifecycle-skill models (work/review inherit, push haiku)"
```

---

### Task 2: Create the remaining five per-step agents

**Files:**
- Create: `agents/auto-work.md`, `agents/auto-review.md`, `agents/auto-feedback.md`, `agents/auto-validate.md`, `agents/auto-finish.md`

**Interfaces:**
- Produces: agents `auto-work` (opus), `auto-review` (opus), `auto-feedback` (sonnet), `auto-validate` (sonnet), `auto-finish` (sonnet), each spawned by name via `Task`, each returning its lifecycle skill's handshake.

- [ ] **Step 1: Create `agents/auto-work.md`**

```markdown
---
name: auto-work
description: Autonomous-run WORK step. Implements a ticket end-to-end and opens the PR in autonomous mode, then returns the ccmagic status handshake. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: opus
skills:
  - ccmagic:work-ticket
  - ccmagic:debug
tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

You are running the **work** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `work-ticket` procedure in autonomous mode** (its "Autonomous mode" section), using the grounding block in your task prompt. For the Debugging path, follow the preloaded `debug` procedure inline. Implement, validate scope against the ticket, and open the PR.

Because you were invoked with an autonomous grounding block, you are **orchestrated** — on `needs-human`, emit the handshake and stop; do not park the ticket yourself.

Defer full code review to the orchestrator's dedicated review step — keep only work-ticket's lightweight self-check here (do not run a separate deep review). Follow the preloaded procedures directly; do not re-invoke `/ccmagic:work-ticket` or `/ccmagic:debug` as skills.

Return **only** the work-ticket autonomous handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: <one line — the PR URL on done; the blocking decision on needs-human>
follow_ups: [<any tickets or deferrals noted>]
```

Grounding block (your task prompt):
```

- [ ] **Step 2: Create `agents/auto-review.md`**

```markdown
---
name: auto-review
description: Autonomous-run REVIEW step. Runs the ticket-grounded code review in autonomous mode and returns the clean | fixable-findings | needs-human verdict. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: opus
skills:
  - ccmagic:review-ticket
  - ccmagic:review
tools: Read, Edit, Bash, Glob, Grep, Task
---

You are running the **review** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `review-ticket` procedure in autonomous mode**, which itself uses the preloaded `review` procedure — run `review`'s pipeline inline (spawn its parallel analysis subagents via your `Task` tool as `review` describes). Use the grounding block in your task prompt.

Because you were invoked with an autonomous grounding block, you are **orchestrated** — on `needs-human`, emit the verdict and stop; do not park the ticket yourself. Report and verdict only; do not mutate code (the orchestrator applies fixes).

Follow the preloaded procedures directly; do not re-invoke `/ccmagic:review-ticket` or `/ccmagic:review` as skills.

Return **only** the review-ticket verdict handshake as the last thing in your output, verbatim:

```
status: clean | fixable-findings | needs-human
reason: <one line, when not clean>
follow_ups: [<any tickets or deferrals noted>]
```

Grounding block (your task prompt):
```

- [ ] **Step 3: Create `agents/auto-feedback.md`**

```markdown
---
name: auto-feedback
description: Autonomous-run PR-FEEDBACK step. Applies reviewer feedback, replies, files follow-ups, and pushes in autonomous mode, then returns the ccmagic status handshake with counts. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: sonnet
skills:
  - ccmagic:pr-feedback
  - ccmagic:push
tools: Read, Edit, Bash, Glob, Grep, Task
---

You are running the **pr-feedback** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `pr-feedback` procedure in autonomous mode** (triage → execute): apply address-now fixes, reply to declined/question threads, file one follow-up ticket per deferred/out-of-scope item, then push using the preloaded `push` procedure inline. Use the grounding block in your task prompt.

Because you were invoked with an autonomous grounding block, you are **orchestrated** — on `needs-human` (a genuine reviewer tie), emit the handshake and stop; do not park the ticket yourself.

Follow the preloaded procedures directly; do not re-invoke `/ccmagic:pr-feedback` or `/ccmagic:push` as skills.

Return **only** the pr-feedback autonomous handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: applied {A} / declined {D} / deferred {F}   (or the blocking tie on needs-human)
follow_ups: [<follow-up ticket ids filed>]
```

Grounding block (your task prompt):
```

- [ ] **Step 4: Create `agents/auto-validate.md`**

```markdown
---
name: auto-validate
description: Autonomous-run VALIDATE step. Runs pre-CI validation (lint/types/tests/build) and returns a done | needs-human handshake. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: sonnet
skills:
  - ccmagic:validate
tools: Read, Bash, Glob, Grep, Task
---

You are running the **validate** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `validate` procedure** to run the project's checks. Use the grounding block in your task prompt for context.

Report the outcome as a handshake: `done` when validation passes; `needs-human` when it fails with a one-line summary of the failing checks (the orchestrator decides whether to fix-and-retry or park). Follow the preloaded procedure directly; do not re-invoke `/ccmagic:validate` as a skill.

Return **only** this handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: <one line — "validation passed" on done; the failing checks on needs-human>
follow_ups: []
```

Grounding block (your task prompt):
```

- [ ] **Step 5: Create `agents/auto-finish.md`**

```markdown
---
name: auto-finish
description: Autonomous-run FINISH step. Enforces the merge gate and merges (or returns needs-human) in autonomous mode, then returns the ccmagic status handshake. Spawned by /ccmagic:auto-ticket. Not for direct human use.
model: sonnet
skills:
  - ccmagic:finish-ticket
tools: Read, Edit, Bash, Glob, Grep
---

You are running the **finish** step of an autonomous ticket run driven by `/ccmagic:auto-ticket`.

Follow the **preloaded `finish-ticket` procedure in autonomous mode**: enforce the merge gate (mergeable + CI green + no unaddressed change-requests), take the Done path, merge with the strategy the skill determines, and auto-resolve only trivial conflicts. Use the grounding block in your task prompt.

Because you were invoked with an autonomous grounding block, you are **orchestrated** — on `needs-human` (gate not satisfied, or a business-logic conflict), do NOT merge and do NOT park the ticket yourself; emit the handshake and stop so the orchestrator routes it.

Follow the preloaded procedure directly; do not re-invoke `/ccmagic:finish-ticket` as a skill.

Return **only** the finish-ticket autonomous handshake as the last thing in your output, verbatim:

```
status: done | needs-human
reason: <one line — "merged into {base}" on done; the blockers on needs-human>
follow_ups: []
```

Grounding block (your task prompt):
```

- [ ] **Step 6: Verify all six agents parse, carry the right model, and (except review/feedback/work which legitimately fan out) omit the Skill tool**

Run:
```bash
cd /Users/devon/git/ccmagic
python3 - <<'PY'
import yaml, pathlib
want = {"auto-work":"opus","auto-review":"opus","auto-feedback":"sonnet",
        "auto-validate":"sonnet","auto-finish":"sonnet","auto-push":"haiku"}
for name, model in want.items():
    fm = yaml.safe_load(pathlib.Path(f"agents/{name}.md").read_text().split("---")[1])
    assert fm["name"] == name, (name, fm)
    assert fm["model"] == model, (name, fm["model"], "want", model)
    assert "Skill" not in str(fm.get("tools","")), f"{name} must not carry the Skill tool"
    assert fm.get("skills"), f"{name} must preload its skill(s)"
print("all six agents OK:", list(want))
PY
```
Expected: `all six agents OK: [...]` with no assertion error.

- [ ] **Step 7: Commit**

```bash
cd /Users/devon/git/ccmagic
git add agents/auto-work.md agents/auto-review.md agents/auto-feedback.md agents/auto-validate.md agents/auto-finish.md
git commit -m "feat(auto-ticket): add per-step wrapper agents for work/review/feedback/validate/finish"
```

---

### Task 3: Wire all steps through `run_step` + config loading

**Files:**
- Modify: `skills/auto-ticket/SKILL.md` (generalize Step execution mode to all steps; extend Step 0 config load with `fork_steps` + `model_<step>`)

**Interfaces:**
- Consumes: all six agents from Tasks 1–2.
- Produces: full fork/inline routing for every step; config keys `fork_steps`, `model_work_ticket`, `model_review_ticket`, `model_pr_feedback`, `model_finish_ticket`, `model_validate`, `model_push`.

- [ ] **Step 1: Update the registry note to cover all steps**

In `skills/auto-ticket/SKILL.md`, replace the final sentence of the "Per-step agent registry" subsection ("Only `push` is wired in this iteration; the rest are added in a later change.") with:
```markdown
All six steps route through `run_step`. When `fork_steps` is false, every step falls back to an inline `Skill` invocation in this orchestrator's context.
```

- [ ] **Step 2: Extend Step 0 config loading**

In `skills/auto-ticket/SKILL.md`, in Step 0 item 3 ("Load config"), append to the keys list:
```markdown
, `fork_steps` (bool, default `true`), and the per-step model overrides `model_work_ticket`, `model_review_ticket`, `model_pr_feedback`, `model_finish_ticket`, `model_validate`, `model_push` (each defaulting to the registry value)
```

- [ ] **Step 3: Point each step invocation at `run_step`**

In `skills/auto-ticket/SKILL.md`, for each step (Step 1 work, Step 3 review, Step 4a pr-feedback, Step 4b validate, Step 5 finish, and the Step 3/4 push commits), ensure the invocation reads "run the {step} step via `run_step`" rather than a bare "Invoke `/ccmagic:<skill>`". Add this sentence once at the top of Step 1:
```markdown
> Each step below is executed via `run_step` (see *Step execution mode*): forked to its per-step agent when `fork_steps` is true, inline otherwise. The grounding block and handshake parsing are identical either way.
```

- [ ] **Step 4: Verify the wiring references every agent and config key**

Run:
```bash
cd /Users/devon/git/ccmagic
for a in auto-work auto-review auto-feedback auto-validate auto-finish auto-push; do
  grep -q "$a" skills/auto-ticket/SKILL.md && echo "ref $a: OK" || echo "ref $a: MISSING"
done
for k in fork_steps model_work_ticket model_review_ticket model_pr_feedback model_finish_ticket model_validate model_push; do
  grep -q "$k" skills/auto-ticket/SKILL.md && echo "key $k: OK" || echo "key $k: MISSING"
done
```
Expected: every line ends `OK`.

- [ ] **Step 5: Commit**

```bash
cd /Users/devon/git/ccmagic
git add skills/auto-ticket/SKILL.md
git commit -m "feat(auto-ticket): route every step through run_step with per-step models"
```

---

### Task 4: Update the autonomous contract

**Files:**
- Modify: `skills/auto-ticket/autonomous-contract.md`

- [ ] **Step 1: Extend the §5 config table**

Add these rows to the §5 "Config keys" table in `skills/auto-ticket/autonomous-contract.md`:
```markdown
| `fork_steps` | bool | `true` | Run each lifecycle step in its own forked subagent; `false` runs them inline in the orchestrator. |
| `model_work_ticket` | string | `opus` | Model for the work step's agent (`auto-work`). |
| `model_review_ticket` | string | `opus` | Model for the review step's agent (`auto-review`). |
| `model_pr_feedback` | string | `sonnet` | Model for the pr-feedback step's agent (`auto-feedback`). |
| `model_finish_ticket` | string | `sonnet` | Model for the finish step's agent (`auto-finish`). |
| `model_validate` | string | `sonnet` | Model for the validate step's agent (`auto-validate`). |
| `model_push` | string | `haiku` | Model for the push step's agent (`auto-push`). |
```

- [ ] **Step 2: Add a "step execution" note after §2**

Add this paragraph at the end of §2 (The grounding block) in `autonomous-contract.md`:
```markdown
When `fork_steps` is true, `auto-ticket` runs each step in a per-step subagent (`agents/auto-*.md`) on the step's model, passing this grounding block as the child's task prompt and reading back the child's handshake (§3). The child agents preload their lifecycle skill rather than invoking it, so the step runs on the agent's model. With `fork_steps: false`, steps run inline via the `Skill` tool. Either way the grounding block and handshake are identical.
```

- [ ] **Step 3: Verify**

Run:
```bash
cd /Users/devon/git/ccmagic
grep -c 'fork_steps\|model_work_ticket\|model_push' skills/auto-ticket/autonomous-contract.md
c=$(grep -c '```' skills/auto-ticket/autonomous-contract.md); echo "fences: $([ $((c%2)) -eq 0 ] && echo OK || echo ODD)"
```
Expected: a count ≥ 3 and `fences: OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/devon/git/ccmagic
git add skills/auto-ticket/autonomous-contract.md
git commit -m "docs(auto-ticket): document fork_steps + per-step model keys in the contract"
```

---

### Task 5: Update user-facing docs (config example + README)

**Files:**
- Modify: `docs/ccmagic.local.md.example`, `README.md`

- [ ] **Step 1: Add the keys to the config example frontmatter**

In `docs/ccmagic.local.md.example`, after the `max_feedback_passes` block (before the closing `---`), add:
```yaml
# --- Per-step execution (used by /ccmagic:auto-ticket) ---
# Run each lifecycle step in its own forked subagent (default true). Set false
# to run every step inline in one context (the 3.1.0 behavior).
fork_steps: true
# Per-step model (defaults shown = the Balanced mapping; set only to override):
# model_work_ticket:   opus
# model_review_ticket: opus
# model_pr_feedback:   sonnet
# model_finish_ticket: sonnet
# model_validate:      sonnet
# model_push:          haiku
```

- [ ] **Step 2: Add the keys to the "Recognized keys" table**

In `docs/ccmagic.local.md.example`, add to the recognized-keys table:
```markdown
| `fork_steps` | Run each `auto-ticket` step in its own forked subagent. | `true` |
| `model_<step>` | Per-step model override (`model_work_ticket` … `model_push`). | Balanced mapping |
```

- [ ] **Step 3: Extend the README Autonomous-mode section**

In `README.md`, in the "Autonomous mode" section (after the config YAML block), add:
```markdown
### Per-step subagents and models

By default `auto-ticket` runs each lifecycle step in its own **forked subagent** on a best-fit **model** — strong models where judgment matters, light ones for mechanical steps — which keeps the orchestrator's context lean on long unattended runs and puts the right model on each step:

| Step | Default model |
|---|---|
| work-ticket / review-ticket | `opus` |
| pr-feedback / finish-ticket / validate | `sonnet` |
| push | `haiku` |

Set `fork_steps: false` to run every step inline in one context instead, or override any step with `model_<step>` (e.g. `model_pr_feedback: opus`).
```

- [ ] **Step 4: Verify**

Run:
```bash
cd /Users/devon/git/ccmagic
grep -q 'fork_steps' docs/ccmagic.local.md.example && echo "example: OK"
grep -q 'Per-step subagents and models' README.md && echo "readme: OK"
```
Expected: `example: OK` and `readme: OK`.

- [ ] **Step 5: Commit**

```bash
cd /Users/devon/git/ccmagic
git add docs/ccmagic.local.md.example README.md
git commit -m "docs: document fork_steps + per-step models for auto-ticket"
```

---

### Task 6: CHANGELOG + version bump to 3.2.0

**Files:**
- Modify: `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add the CHANGELOG entry**

Insert above the `## [3.1.0]` heading in `CHANGELOG.md`:
```markdown
## [3.2.0] — 2026-07

### Added

- **Per-step subagents for `/ccmagic:auto-ticket`** — each lifecycle step (work / review / pr-feedback / validate / finish / push) now runs in its own forked subagent on a best-fit model, keeping the orchestrator's context lean on long unattended runs. New thin wrapper agents live in `agents/auto-*.md`; the five lifecycle skills are reused unchanged. Configurable via `fork_steps` (default `true`; `false` restores the 3.1.0 inline flow).
- **Per-step model selection** — Balanced defaults (`opus` for work/review, `sonnet` for pr-feedback/finish/validate, `haiku` for push), overridable per repo with `model_<step>` keys. `auto-ticket` itself is now `context: fork`.

### Changed

- **`skills/auto-ticket/SKILL.md`** — now `context: fork`; every step routes through a `run_step` helper (forked-per-step or inline). The handshake contract is unchanged; it now returns across the subagent boundary.
```

- [ ] **Step 2: Bump the version in both manifests**

Change `"version": "3.1.0"` to `"version": "3.2.0"` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

- [ ] **Step 3: Verify version + JSON validity**

Run:
```bash
cd /Users/devon/git/ccmagic
python3 -c "import json;a=json.load(open('.claude-plugin/plugin.json'));b=json.load(open('.claude-plugin/marketplace.json'));assert a['version']=='3.2.0' and b['plugins'][0]['version']=='3.2.0';print('versions 3.2.0 OK')"
grep -m1 '^## \[' CHANGELOG.md
```
Expected: `versions 3.2.0 OK` and `## [3.2.0] — 2026-07`.

- [ ] **Step 4: Commit**

```bash
cd /Users/devon/git/ccmagic
git add CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: document per-step subagents; bump to 3.2.0"
```

---

### Task 7: Full structural sweep + end-to-end smoke test

**Files:** none (verification only)

- [ ] **Step 1: Structural sweep**

Run:
```bash
cd /Users/devon/git/ccmagic
echo "agents:"; ls agents/*.md | wc -l
echo "skills:"; find skills -name SKILL.md | wc -l
for f in skills/auto-ticket/SKILL.md skills/auto-ticket/autonomous-contract.md; do
  c=$(grep -c '```' "$f"); echo "$f fences: $([ $((c%2)) -eq 0 ] && echo OK || echo ODD)"
done
python3 - <<'PY'
import yaml, pathlib, glob
for p in glob.glob("agents/*.md"):
    yaml.safe_load(pathlib.Path(p).read_text().split("---")[1])
print("all agent frontmatter parses")
PY
```
Expected: `agents: 6`, `skills: 24`, both fences `OK`, `all agent frontmatter parses`.

- [ ] **Step 2: Local plugin load-test**

Run `claude --plugin-dir ./` and confirm: `/ccmagic:auto-ticket` loads, and the six `auto-*` agents are listed as available agents. (Manual — no assertion; confirm no load errors.)

- [ ] **Step 3: End-to-end smoke test (interactive, real ticket)**

In the MagicMenu repo (Linear MCP connected), with `.claude/ccmagic.local.md` set to `tracker: linear`, `fork_steps: true`, `needs_human_label: needs-human`:
1. Run `/ccmagic:auto-ticket MM-305` (the test-only ticket — safest happy path).
2. In the task pane, confirm each step spawns its `auto-*` child subagent on the mapped model (work/review on opus, feedback/validate/finish on sonnet, push on haiku).
3. Confirm each child returns a handshake the orchestrator parses, and the run ends **merged** or **parked** (never hung).
4. Re-run with `fork_steps: false` and confirm steps run inline (no child subagents), same outcome.
5. Optionally run `/ccmagic:auto-ticket ENG-31` and confirm it **parks** (too large → needs-human) without merging.

- [ ] **Step 4: Final commit (if the smoke test required tweaks)**

```bash
cd /Users/devon/git/ccmagic
git add -A && git commit -m "fix(auto-ticket): smoke-test adjustments for per-step subagents" || echo "no changes"
```

---

## Self-Review

**1. Spec coverage:**
- Per-step subagents (fork) → Tasks 1–3. ✓
- `fork_steps` global toggle default true → Task 1 (section), Task 3 (all steps), Task 5 (docs). ✓
- Per-step Balanced models + `model_<step>` overrides → Task 2 (agent frontmatter), Task 3 (config), Task 4/5 (docs). ✓
- `auto-ticket` → `context: fork` → Task 1 Step 3. ✓
- Preload-not-invoke model safety → agent bodies (Tasks 1–2) + Global Constraints. ✓
- Handshake unchanged, crosses boundary → Task 1 section, Task 4 note. ✓
- Contract §5 + step-execution note → Task 4. ✓
- Config example + README + CHANGELOG + version → Tasks 5–6. ✓
- Risk #1 (model clobber) validated early → Task 1 Step 6 gate. ✓
- Risk #2 (best-effort override) → Task 1 registry note + Global Constraints. ✓
- Behavior change (fork output = returned summary) → covered by run itself; documented in README/CHANGELOG. ✓
- Non-goals (no per-step fork granularity, no selector, no interactive change) → Global Constraints + additive-only edits. ✓

**2. Placeholder scan:** Agent bodies and edits carry actual content; `{A}/{D}/{F}`, `{base}`, `{step}` are the handshake/template tokens copied verbatim from the existing skills, not plan placeholders. No TBD/TODO.

**3. Type consistency:** Agent names (`auto-work`/`auto-review`/`auto-feedback`/`auto-validate`/`auto-finish`/`auto-push`), config keys (`fork_steps`, `model_<step>`), and default models are identical across the registry (Task 1), agent frontmatter (Tasks 1–2), config load (Task 3), contract (Task 4), docs (Task 5), and verification greps. ✓
