# Baseline quality checklist

A baseline spec describes what the code does today, at a named commit, in the shape OpenSpec needs so that later changes can `MODIFY`, `REMOVE`, or `RENAME` its requirements and `openspec archive` applies cleanly. It is not a design document, a bug list, or a record of intent. Apply every item below while authoring, and again before Stop 2.

## Why names are identifiers

- `openspec archive` matches a MODIFIED requirement to the main spec by its exact header text. A name that does not match aborts the archive.
- A MODIFIED block replaces the whole requirement, and archive refuses it when a scenario name in the main spec is missing from the block (OpenSpec 1.13.2). Renaming a scenario fails `validate --strict`; keeping the name and changing the body archives cleanly.
- Reeve copies every delta requirement, body and scenarios, into generated ticket bodies, and rewrites `&`, `@`, `<`, `>`, dashes, and markdown in them. Large blocks make large tickets; names holding those characters render differently from how they are written.

So: name requirements by concern and scenarios by condition, never by a value or an outcome. Values change; concerns and conditions do not.

## Capability granularity

A capability is a boundary of observable behavior with its own entry point (a route group, a listening port, a scheduled job, a filter or middleware, a CLI command, a queue consumer, a rendering pipeline) and the state it owns. It is not a package, a class, or a layer. Size it so a typical change touches one or two capabilities and a spec has 3 to 12 requirements. Split when two families of configuration keys govern it or when it mixes a mutating path with a read-only one; merge when it would have fewer than three requirements and no state of its own. A utility package often spreads over several capabilities; follow the behavior, not the folder.

## Per capability

1. Folder name: single-segment kebab-case, a behavior noun (`abuse-protection`, not `abuse-manager`), not one of `as-delegation`, `label-based-prompt`, `as-refine`, `linear`, `profiles` (Reeve rejects those in change names).
2. The file is `# <name> Specification`, then `## Purpose` of at least 50 characters saying what the capability does, ending with "It describes the behavior of the current code, not intended behavior.", then `## Requirements`. Nothing else: no notes, no evidence, no extra sections.
3. 3 to 12 requirements; otherwise split or merge and re-propose the map.

## Per requirement

4. Named by concern, unique in the spec, plain words; no value, no outcome, no backtick, URL, `@`, `<`, `>`, `&`, or trailing punctuation. "Session timer", not "Session lives 10 minutes"; "Unused retry settings", not "retry.enabled is ignored".
5. Body of one to three sentences, under 500 characters, with SHALL or MUST (strict validation requires it in the body). Name each governing configuration key with its shipped default in parentheses (the value in the base configuration file, or the code default when the file does not set it), and mark a constant "(a fixed value)".
6. States current behavior, bugs included. Never "should", "bug", "fix", "intended", "incorrectly", or "currently" (the whole file is current).
7. No code, file, class, method, line number, date, or citation in the body. Prose between the header and the first scenario is copied blindly by every later MODIFIED delta.
8. 1 to 4 scenarios, each a branch of this requirement's decision. One requirement per decision a client, operator, or sender can observe: not one per method, endpoint, or field (an endpoint with a flag check, a counter, and a send is three decisions).

## Per scenario

9. Named by the condition that selects the branch ("Threshold crossed", "Blank sender", "Expired but not yet probed"), never by the value or outcome ("51st hit blocks", "Returns 421"). Unique within its requirement.
10. Exactly one `- **WHEN**` and one `- **THEN**` line, optional `- **AND**` lines; no nested bullets, fences, tables, or lines starting with `#`.
11. The THEN names the observable result with the exact status, key, header, or text wherever a client or test depends on it.

## What to include

Status codes; response content type and cache headers; field names, types (a string holding digits is a string), and literal keys with their casing; exact text only when it is machine-read or asserted by a test; configuration keys with the shipped default; fixed limits, caps, TTLs, schedules, and units; check ordering when it changes the outcome; what is counted, logged, or persisted when it affects a later decision; which stage does the work only when it changes what a client sees.

## What to leave out (list each in the evidence under "Left out of the spec on purpose" or "Not specified")

Class and method names, file paths, thread pool sizes, data structures, log text, framework annotations, anything observable only in a debugger or under a race (a race goes in the evidence as `Looks unintended`), UI copy and layout (a message a client parses is not copy), third-party internals, deployment and infrastructure files, cross-cutting wiring (executors, scheduler beans, logging configuration), and unreachable code.

## Behavior that looks like a bug

State it as the code behaves, in neutral words, and flag it in the evidence under `Looks unintended` with the citation. If the baseline described the intended behavior, the fix would look like a no-op and the archive would record no change.

## Configuration, dead settings, and secrets

- A key that governs a qualitatively different mode gets one scenario per mode. Per-environment values go in the evidence under `Config`.
- A setting an operator would expect to matter but that has no effect is specified as "has no effect" under a concern-shaped name, so a later change that wires it is a MODIFIED delta against a real requirement. Unreachable code nobody would expect to act (an unused constant, a method with no caller) goes under "Not specified" in the evidence.
- Never copy a secret. Refer to credential keys by name. Name them under "Secrets in configuration" and warn at Stop 2.

## Error paths and security

Every refusal, rejection, timeout, and fallback is a scenario of the requirement that owns the decision, with the observable result. An error whose visible form depends on a library is stated as far as the code decides it; the rest is an `Open question`. A swallowed exception is a scenario when it changes what the caller sees (a failed send that still returns 200). Security-relevant behavior is stated flatly ("the system SHALL NOT authenticate requests to the admin routes"), with a `Security` note in the evidence.

## After writing each capability

12. Every requirement and scenario has its evidence line with at least one resolvable citation and a test reference or `UNTESTED` (format: `evidence-format.md`).
13. Every `Looks unintended`, `Open question`, `Docs disagree`, `Config`, and `Security` item from the extraction is in the evidence or consciously dropped.
14. `openspec validate --all --strict --no-interactive` passes, `ccm-baseline-check` reports no finding, and nothing outside `openspec/` and `docs/openspec-baseline.md` changed. A finding is fixed, never silenced: no placeholder text, no Purpose padded with filler, no scenario dropped to satisfy uniqueness instead of being renamed by condition.
