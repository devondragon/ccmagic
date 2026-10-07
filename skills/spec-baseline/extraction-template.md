# Extraction template

The prompt for one extraction subagent, one per accepted capability. Fill in the `{placeholders}` and send the text below the line verbatim; do not shorten the rules. Dispatch with the `Explore` agent type (it has no write tools) and `model: "sonnet"`, at most 4 at once, all of a batch in one message, and wait for every agent in the batch to return before the next batch or any authoring. `{neighbors}` lists only capabilities in the map, each with its purpose; in one-capability mode that includes the rows marked `not yet specified`.

---

You are extracting the current behavior of one capability of the repository at `{repo_root}` (commit `{baseline_sha}`) so that a baseline specification can be written from your notes. You only read. Do not create, edit, or delete any file, and do not run any command that changes the repository.

**Capability:** `{capability}`
**Purpose (observable behavior):** {purpose}
**Start from these files:** {implementing_files}
**Tests that may pin it:** {tests}
**Other capabilities in the map (behavior that belongs to one of these may be left out):** {neighbors}
**Configuration files:** {config_files}
**Docs (the repository's doc files and, where known, their lines about this capability):** {docs}

Read the code for facts. Read the docs above to compare them with the code: for each doc claim about this capability, confirm it against the code or report a `Docs disagree` flag with both the doc citation and the code citation. A capability with doc lines and no `Docs disagree` or confirmation in your notes is incomplete.

## Output

Return one numbered list of observable behaviors, then the four sections below it. Nothing else.

For each behavior:

```
N. <one present-tense sentence: what a client, operator, or sender observes, including the exact status, header, field name, key, limit, unit, or text where it matters>
   Code: `path:line` or `path:line-line` (repository-relative, full path, at the commit above), one or more
   Test: `path/to/test.file::test title` or `TestClass.method` for each test that asserts it, or UNTESTED
   Branches: <each condition that changes the outcome, one per line, if more than one>
   Flags: <zero or more of the lines below>
     Looks unintended: <why a maintainer would probably not have chosen this>
     Open question: <what the code does not settle>
     Docs disagree: `doc/path:line` says <...>; the code (`path:line`) <...>
     Config: `key` = <value> in <file or profile> (`path:line`), for each file or profile that sets it; the code default when none does
     Security: <what a reviewer should look at>
```

Rules:

1. Every behavior needs at least one citation with a full repository-relative path and a real line number you read. Never abbreviate a path after its first use; never cite from memory.
2. A test counts only if it asserts the behavior. A test that merely executes the code is not a pin: say UNTESTED and name the test in parentheses.
3. State bugs as behavior, in neutral words, and flag them `Looks unintended`. Do not describe a fix or the intended behavior.
4. A setting that is read but has no effect, or never read at all, is a behavior ("`key` has no effect"). Code with no caller is not a behavior: list it under "Unreachable". Before calling anything unreachable, unused, or without effect, search the whole repository for its callers or readers and say what you searched for.
5. **Never copy a credential, token, password, API key, or other secret value into your output, and never copy a personal email address, phone number, or account identifier.** Name the key or constant and say it holds a credential-looking value or a hard-coded personal address.
6. Leave out log text, thread pool sizes, class and method names as behavior, and anything observable only in a debugger; a race goes in as a behavior flagged `Looks unintended` with the interleaving.
7. For input variants (spaces, case, null, empty, malformed) and for each refusal or error status, trace every check on the path from the entry point, in order, and cite each; say which check decides first.
8. Order check sequences as the code runs them when the order changes the outcome.
9. Leave a behavior out as another capability's only when that capability is in the list above, and then list it under "Capability boundary" with the capability's name. A behavior that belongs to no listed capability is extracted here, with a boundary note saying where you think it belongs.

After the list:

- **Unreachable:** code in these files with no caller or no effect nobody would expect, with `path:line` and the search that found no caller.
- **Not behavior:** wiring, logging, and infrastructure you read and left out, one line each.
- **Secrets seen:** configuration keys whose values look like credentials, by key name only.
- **Capability boundary:** each behavior you left out because it belongs to a listed capability, under that capability's name, one line each with `path:line`; and behavior of this capability you found outside the start files, with `path:line`. Say plainly if the capability as drawn looks wrong (it should be split, merged, or renamed).
