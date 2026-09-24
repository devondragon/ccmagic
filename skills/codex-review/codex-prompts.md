# Codex Review Prompts

The dimension prompts live in `bin/ccm-external-review`, which feeds them to Codex and Gemini. Edit them there. To see the exact text a pass sends:

```bash
ccm-external-review --print-prompt security   # or architecture, correctness, errors, tests, deps, adversarial
```

| Dimension | Scope |
|---|---|
| `security` | Security vulnerabilities only, each with entry point, data flow, preconditions, and exploit scenario |
| `architecture` | Coupling, dependency direction, API design, error boundaries, dead code, missing abstractions, configuration |
| `correctness` | Logic errors, nil access, races, leaks, error-handling gaps, edge cases, each with a triggering scenario |
| `errors` | Swallowed or missing error handling, propagation, retries, timeouts, degradation, cleanup, crash paths |
| `tests` | Significant coverage gaps on critical paths, error paths, and edge cases |
| `deps` | Dependency configuration health: pinning, deprecated or duplicate packages, lockfiles, build tool config |
| `adversarial` | The single `/ccmagic:review` Step 3.5 pass: ways the branch's changes fail in production |

Every dimension prompt returns at most 10 findings, prints exactly `No actionable findings.` when there are none, and ends with the shared finding table format (`| Severity | Confidence | Location | Issue | Trigger | Fix | Test |`). With `--conventions FILE`, the project conventions are appended before the table format.

**Every prompt opens with the same "do not load any installed skill" line — keep it, and add it to any new dimension you write.** Codex CLI runs its own skill auto-matcher: at the start of a run it compares the prompt against the `description` in every `~/.codex/skills/*/SKILL.md` and silently loads whichever one matches. A prompt that opens "Review this code for … issues" is a near-verbatim match for common review skills (GSD's `gsd-code-review` describes itself as *"Review source files changed during a phase for bugs, security issues, and code quality problems"*). When it matches, Codex reads that skill and its multi-hundred-line companion workflow *before* looking at the diff, then follows those instructions instead of the dimension prompt — exploring unrelated files until the `timeout` kills it, and returning zero findings. Observed against the correctness prompt: the first three tool calls of the run were `sed` on `~/.codex/skills/gsd-code-review/SKILL.md` and `~/.codex/gsd-core/workflows/code-review.md`. The hijack is intermittent, so one clean run does not prove the line is redundant. There is no CLI flag to disable it — `codex exec --disable skills` errors with `Unknown feature flag: skills` — so the suppression has to live in the prompt text. It is harmless to the other CLIs these prompts are fed to.
