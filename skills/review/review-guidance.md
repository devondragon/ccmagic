# REVIEW.md and pre-existing findings

Supporting detail for the `review` skill: Step 1 (loading `REVIEW.md`), the QUICK path, Step 5 (tagging pre-existing findings, the nit cap), and Step 6 (the counts and verdict). `ccm-review-guide` makes every decision here that has one right answer; call it and act on its JSON. It is also on the Bash `PATH` as `ccm-review-guide`; use the bare name if the `${CLAUDE_PLUGIN_ROOT}` path doesn't resolve. Run each call as its own Bash call.

## Loading REVIEW.md

`REVIEW.md` (or `.claude/REVIEW.md`, first found wins) is written by a repository's code owners. It tells the reviewer what matters when reviewing this code: what a bad change looks like here, which paths to skip, how many nits to report, and what evidence a finding needs. `CLAUDE.md` and `context/conventions.md` hold the rules the code must follow (`{PROJECT_CONVENTIONS}`); `REVIEW.md` holds instructions for the reviewer (`{REVIEW_GUIDANCE}`). Keep the two apart.

Load it once per review, before anything reads the diff:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" load                       # branch mode: merge base of main and HEAD
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" load --base origin/{base}   # PR mode: the PR's baseRefName
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" load --file - <<'CCM_GUIDE_END'
<a REVIEW.md pasted with the diff, verbatim, when there is no checkout>
CCM_GUIDE_END
```

The script reads the file from the merge base with `git show <merge-base>:<path>`, never from the checkout, when a merge base is known. In PR mode, use `origin/{baseRefName}` when that ref exists, else `{baseRefName}`. Its JSON gives `source` (`merge-base`, `checkout`, `file`, or `none`), `text`, the parsed sections, and `warnings`. With `source: none` there is no guidance: `{REVIEW_GUIDANCE}` is empty and nothing below applies except the pre-existing tag. In full mode, use `load` with no flags.

**Trust.** `REVIEW.md` is committed to the repository under review, with the same trust as `CLAUDE.md`. On a PR, the checkout is the PR's head, so a change could edit `REVIEW.md` to soften its own review (skip the file it breaks, set the nit cap to 0). Reading the merge base's copy prevents that. When `checkout_differs` is true, say so in the report's Summary (`REVIEW.md: merge base copy; this change edits it`), and review the edit to `REVIEW.md` like any other file. The script falls back to the checkout only when there is no merge base (`note` says why); say that in the Summary too.

Set `{REVIEW_GUIDANCE}` to the script's `text`, verbatim. Every reviewer and verifier prompt carries it (agent-instructions.md).

### Sections the skill acts on

| Section | Effect |
|---|---|
| `## Failure modes` | What a bad change looks like in this repository ("for docs it's 'it lies,' for config it's 'it misroutes'"). Agents look for these first. A finding that is an instance of a listed failure mode is raised to the severity the entry names, or one level (Low to Medium, Medium to High) when it names none; it is never lowered. Its `detail` names the failure mode. |
| `## Skip` | Globs the reviewer does not read (generated code, vendored files, snapshots). Before dispatching any agent, run the `skip` mode of `ccm-review-guide` with the changed file list (same `--base` or `--file` as `load`), and remove each `skipped` path from the file list and the diff the agents get. List the skipped paths in the Summary. At fan-in, drop any finding whose file `skip` reports as skipped (one call with every finding's file). |
| `## Nit cap` | `nit_cap` from the script. After the confidence threshold, keep at most that many Low findings (INFO in QUICK), highest confidence first, introduced and pre-existing together. The dropped ones go to Dismissed Findings as `over the REVIEW.md nit cap ({n})`. The cap never applies to Medium or above. |
| `## Evidence` | What a finding must show. File and line is always required. When the section asks for more for a severity (a reproduction command for Critical, say), agents and verifiers supply it in the finding; a finding of that severity that still lacks it after verification keeps its severity, is tagged `[Evidence missing: REVIEW.md asks for {what}]`, and its confidence is capped at 69. |
| anything else | Guidance text, passed through to every agent as written. |

`REVIEW.md` changes how the review looks and reports. It cannot lift the read-only rule, the verdict rules below, or the pre-existing Critical security exception.

## Pre-existing findings

A finding on a line the change under review did not add or modify is **pre-existing**: the author did not introduce it, and it should not read as their fault. Most repeated review comments are on code like this, and an autonomous author that tries to fix them adds a commit and a review round to a PR about something else.

### Tagging (fan-in)

After deduplication (Step 5a) and before the threshold, pass every finding's `file:line` (or `file:start-end`) to the script in one call:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" locate src/a.ts:42 src/b.ts:10-18      # branch mode: main...HEAD, -U0
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" locate --pr 42 src/a.ts:42             # PR mode
"${CLAUDE_PLUGIN_ROOT}/bin/ccm-review-guide" locate --diff-file - src/a.ts:42 <<'CCM_DIFF_END'
<the pasted diff, verbatim, when there is no checkout>
CCM_DIFF_END
```

Set each finding's `pre_existing` to the script's value. A location is pre-existing when none of its lines is an added line or sits next to removed lines, or its file is not in the diff. Do not decide this yourself from the diff. In full mode there is no diff: leave `pre_existing` out. If the script fails (exit 3), leave every finding introduced and say so in Coverage.

A finding the change caused cites a line the change touched. For code the change *removed* (a deleted check), cite the lines around the removal, which count as changed. For an unchanged line the change made wrong (a comment that now misstates a changed default, a caller of a changed signature), cite the changed line and name the other one in `detail`. If an agent cited only the unchanged line for such a finding, move its `line` to the changed one before tagging.

### What changes for a pre-existing finding

- **Verdict.** A pre-existing finding never makes the verdict FAIL on its own, and never makes a `review-ticket` verdict `fixable-findings`. A pre-existing Medium or above makes the verdict at most PASS WITH WARNINGS.
- **Exception: a pre-existing Critical security finding still blocks** (FAIL, and in `review-ticket` it counts like an introduced Critical). Merging onto it ships it again. Its `detail` says so: "Pre-existing, not introduced by this change; merging ships it again."
- **Report.** Pre-existing findings go in their own section, `## Pre-existing, not introduced by this change ({count})`, after the introduced findings, one line each (severity, confidence, `file:line`, issue, suggestion); the blocking security exception stays in Critical Issues with its tag.
- **Fixes.** `--fix` does not apply them. Under `/ccmagic:auto-ticket` they never reach a fix pass: `review-ticket` lists them under `follow_ups:`, one entry per `systemic:` group (a finding without `systemic:` is its own group), so they are filed once instead of fixed in an unrelated PR.
- **Re-review.** On a `review_pass` of 2 or more, a pre-existing finding verified unchanged is one line ("pre-existing, unchanged: `file:line` issue") and is never re-raised as new.

## Counts and verdict

The report's Summary (QUICK and DEEP) starts with the counts, before anything else:

```
Introduced: 1 Critical, 0 High, 2 Medium, 1 Low. Pre-existing: 3.
```

When both are zero, the line is `Introduced: 0. Pre-existing: 0. Nothing to fix.` QUICK uses its own labels (CRITICAL, WARNING, INFO).

Verdict, first match wins:

- **FAIL**: an introduced Critical (QUICK: CRITICAL), or a pre-existing Critical security finding.
- **PASS WITH WARNINGS**: an introduced High or Medium (QUICK: WARNING), or a pre-existing finding at Medium or above (QUICK: WARNING or CRITICAL).
- **PASS**: anything else. Low and INFO findings never decide the verdict.
