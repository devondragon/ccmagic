---
name: help
user-invocable: true
allowed-tools: Read(*), Glob(*), Bash(git:*)
description: Interactive help and command reference with examples
model: sonnet
---

# ccmagic Help

Display the ccmagic skill reference with practical examples and workflow guidance.

## How to use this

If the user asks a freeform question ("how do I X?"), match it to the appropriate skill below. If they invoke `/ccmagic:help` with no arguments, print the full reference. If they invoke `/ccmagic:help <skill-name>`, jump to that skill's section.

## Skill categories

### Tracker workflow

End-to-end ticket lifecycle backed by Linear, GitHub Issues, or JIRA. Auto-detected unless `.claude/ccmagic.local.md` pins a tracker.

**`/ccmagic:work-ticket {TICKET-ID}`**
- **Purpose:** End-to-end ticket workflow — lookup, assign, branch, work, review, PR.
- **When to use:** Starting work on a new ticket from your tracker.
- **Example:** `/ccmagic:work-ticket ENG-123` (Linear/JIRA) or `/ccmagic:work-ticket 42` (GitHub).
- **What it does:** Classifies the ticket (Quick Fix / Complex Feature / Debugging), creates a branch with the right prefix, executes the work (delegating to `/ccmagic:debug` for bugs), validates scope against the ticket, then opens a PR.

**`/ccmagic:review-ticket [TICKET-ID]`**
- **Purpose:** Code review grounded in the ticket's stated scope and acceptance criteria.
- **When to use:** Before merging a branch tied to a tracker ticket — catches scope drift, not just code-quality issues.
- **Example:** `/ccmagic:review-ticket` (auto-detects from branch) or `/ccmagic:review-ticket PROJ-456`.
- **What it does:** Fetches the ticket, extracts AC, runs `/ccmagic:review` with the ticket as the primary intent source, and adds a Ticket-scope drift section (in-scope / out-of-scope / missing-from-ticket).

**`/ccmagic:finish-ticket [--qa]`**
- **Purpose:** Close out a ticket end-to-end after the PR is ready.
- **When to use:** Final step before merging.
- **Example:** `/ccmagic:finish-ticket` (Done path) or `/ccmagic:finish-ticket --qa` (QA path).
- **What it does:** Detects the ticket from the branch, sanity-checks the PR (CI, reviews, scope), confirms disposition, merges, updates the tracker with a comment and final status.

**`/ccmagic:auto-ticket [TICKET-ID]`**
- **Purpose:** Autonomous end-to-end ticket driver — runs the whole cycle unattended.
- **When to use:** Solo-dev / headless (e.g. Cyrus) runs where you want the ticket taken from implementation to merge with no human in the loop.
- **Example:** `/ccmagic:auto-ticket ENG-123` (or omit the ID to detect it from the current branch).
- **What it does:** Invokes `work-ticket → review-ticket → pr-feedback (looped up to `max_feedback_passes`) → finish-ticket`, all in autonomous mode. Merges when the PR is clean and CI is green; otherwise **parks** the ticket (moves it to `needs_human_state`, comments what it's waiting on) instead of guessing or stalling. Every run ends **merged** or **parked-needs-human** — never hung. Configure via `autonomous`, `needs_human_state`, `needs_human_label`, `max_feedback_passes` in `.claude/ccmagic.local.md`.

### Code review & quality

**`/ccmagic:review [branch|full|PR#] [--quick|--deep] [--threshold N]`**
- **Purpose:** Adaptive code review — auto-routes between QUICK (inline checklist) and DEEP (multi-agent pipeline). Biased toward depth.
- **When to use:** Before PR, after major changes, or to audit a PR.
- **Example:** `/ccmagic:review` (auto-route), `/ccmagic:review --deep`, `/ccmagic:review 1234` (review PR #1234).
- **What it does:** Picks QUICK only for clearly trivial changes; otherwise dispatches 4 core agents + conditional specialists + optional Codex CLI + MCP fallback + verification of Critical/High findings.

**`/ccmagic:codex-review [branch|full|PR#] [--focus DIMENSION]`**
- **Purpose:** Multi-model code review (Codex + Gemini + Claude triage).
- **When to use:** High-stakes changes where you want adversarial cross-model agreement.
- **Example:** `/ccmagic:codex-review`, `/ccmagic:codex-review 1234 --focus security`.

**`/ccmagic:pr-feedback [PR#]`**
- **Purpose:** Triage PR review comments and plan fixes for the valid ones.
- **When to use:** After reviewers leave comments.

### Git workflow

**`/ccmagic:push`**
- **Purpose:** Smart commit and push with logical grouping. The commit-format hook validates each commit's subject post-commit (non-blocking).
- **When to use:** Committing finished work.

**`/ccmagic:pr [--draft]`**
- **Purpose:** Create a PR with platform detection (gh/glab) and a smart description.
- **When to use:** After commits are pushed and you're ready for review.

**`/ccmagic:merge [PR#]`**
- **Purpose:** Safely merge an approved PR with strategy-aware branch handling.
- **When to use:** After approval; use `/ccmagic:finish-ticket` instead if a tracker ticket is involved (it merges + updates the ticket).

### Debugging & investigation

**`/ccmagic:debug [bug description] | resume <slug>`**
- **Purpose:** Systematic debugging via scientific method with persistent sessions.
- **When to use:** Any bug investigation — the skill enforces root-cause discipline.
- **Example:** `/ccmagic:debug "checkout fails for users with cart > $1000"`.

**`/ccmagic:analyze-impact [file-path or name]`**
- **Purpose:** Blast-radius and dependency analysis for a file, directory, or uncommitted changes.
- **When to use:** Before risky refactors, or when planning the scope of a PR.

### Codebase knowledge

**`/ccmagic:map-codebase`**
- **Purpose:** Analyze a brownfield codebase and write durable knowledge files (`context/knowledge/STACK.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`).
- **When to use:** First-time ccmagic onboarding, or after major structural changes.
- **What it does:** Three parallel Explore agents extract the tech stack, architecture, and conventions into reference files that `/ccmagic:review` and `/ccmagic:analyze-impact` later consume.

**`/ccmagic:research <topic>`**
- **Purpose:** Deep iterative research with parallel exploration, source evaluation, and confidence scoring.
- **When to use:** Before designing a non-trivial feature, or to investigate a library/pattern.

### Testing & validation

**`/ccmagic:test [pattern] [--coverage] [--watch] [--affected]`**
- **Purpose:** Run tests with framework auto-detection, smart selection, coverage analysis, and failure diagnosis.
- **When to use:** Anytime, but typically before committing or as part of `/ccmagic:validate`.

**`/ccmagic:validate`**
- **Purpose:** Pre-commit/pre-PR validation with parallel checks (lint, types, tests, build).
- **When to use:** Before opening a PR.

### Design & visual QA

**`/ccmagic:design-explore [description] [--count N] [--evolve URL]`**
- **Purpose:** Generate multiple distinct design directions, compare them in the browser, pick a winner before building.
- **Requires:** Chrome DevTools MCP.

**`/ccmagic:design-qa [URL] [--quick|--deep|--diff]`**
- **Purpose:** Design quality audit — catches AI slop, scores visual polish, fixes issues with atomic commits.
- **Requires:** Chrome DevTools MCP.

**`/ccmagic:browser-qa [URL] [--quick|--exhaustive] [--scope PAGE]`**
- **Purpose:** Systematically QA a web app in a real browser — find bugs, fix them, verify with screenshots.
- **Requires:** Chrome DevTools MCP.

### Quick utilities

**`/ccmagic:quick "[task description]"`**
- **Purpose:** Execute an ad-hoc task without ticket overhead.
- **When to use:** One-off changes that don't warrant a tracker ticket.

### Meta

**`/ccmagic:init`**
- **Purpose:** Bootstrap the small set of non-planning project files: `context/conventions.md`, `context/branching.md`, `context/knowledge/`, `.claude/ccmagic.local.md`.
- **When to use:** First-time setup of ccmagic in a project.

**`/ccmagic:doctor`**
- **Purpose:** Diagnose ccmagic setup — config files, tracker integration, commit hook, branch convention.
- **When to use:** When something feels off, or after install.

**`/ccmagic:settings`**
- **Purpose:** Configure ccmagic — default tracker, QA workflow, ticket-ID regex override, model knobs.

**`/ccmagic:help [skill-name]`**
- **Purpose:** This help.

## Typical workflows

### Working a ticket end-to-end

```
/ccmagic:work-ticket ENG-123     # Triage, branch, implement, review, PR
/ccmagic:review-ticket           # Pre-merge: scope drift + code review
/ccmagic:finish-ticket           # Merge + close ticket
```

### Working a ticket autonomously (unattended)

```
/ccmagic:auto-ticket ENG-123     # Whole cycle, no human in the loop.
                                 # Merges if clean + CI green, else parks it for a human.
```

### Quick task (no ticket)

```
/ccmagic:quick "rename the FooBar function to BarFoo across services"
/ccmagic:push
/ccmagic:pr
```

### Onboarding ccmagic to an existing project

```
/ccmagic:init                    # Bootstrap config files
/ccmagic:map-codebase            # Produce knowledge files
/ccmagic:doctor                  # Verify setup
```

### Pre-PR check

```
/ccmagic:validate                # Lint, types, tests, build
/ccmagic:review                  # Adaptive code review
# or, if tied to a ticket:
/ccmagic:review-ticket
```

## Configuration files

ccmagic reads (and creates with `/ccmagic:init`) these files:

| File | Purpose |
|---|---|
| `.claude/ccmagic.local.md` | Per-project config (tracker, ticket URL, QA workflow) |
| `context/conventions.md` | Project coding standards (read by review, codex-review, pr-feedback, push, quick) |
| `context/branching.md` | Branch strategy (read by pr, merge) |
| `context/knowledge/*.md` | Architecture/stack/conventions knowledge (produced by map-codebase; read by review, codex-review, analyze-impact) |
| `CLAUDE.md` (plugin-root) | Canonical commit format and ticket-ID regex |

See `docs/ccmagic.local.md.example` for the config template.
