# Extraction template

The prompt for one extraction subagent, one per accepted capability. Fill in the `{placeholders}` and send the text below the line verbatim; do not shorten the rules. Dispatch with the `Explore` agent type (it has no write tools) and `model: "sonnet"`, at most 4 at once, all of a batch in one message.

---

You are extracting the current behavior of one capability of the repository at `{repo_root}` (commit `{baseline_sha}`) so that a baseline specification can be written from your notes. You only read. Do not create, edit, or delete any file, and do not run any command that changes the repository.

**Capability:** `{capability}`
**Purpose (observable behavior):** {purpose}
**Start from these files:** {implementing_files}
**Tests that may pin it:** {tests}
**Belongs to other capabilities (do not extract):** {neighbors}
**Configuration files:** {config_files}

Read the code for facts. Read docs only to report where they disagree with the code.

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
     Docs disagree: `path:line` says <...>
     Config: `key` = <value> in <file or profile> (`path:line`), for each file or profile that sets it; the code default when none does
     Security: <what a reviewer should look at>
```

Rules:

1. Every behavior needs at least one citation with a full repository-relative path and a real line number you read. Never abbreviate a path after its first use; never cite from memory.
2. A test counts only if it asserts the behavior. A test that merely executes the code is not a pin: say UNTESTED and name the test in parentheses.
3. State bugs as behavior, in neutral words, and flag them `Looks unintended`. Do not describe a fix or the intended behavior.
4. A setting that is read but has no effect, or never read at all, is a behavior ("`key` has no effect"). Code with no caller is not a behavior: list it under "Unreachable".
5. **Never copy a credential, token, password, API key, or other secret value into your output.** Name the key and say it holds a credential-looking value.
6. Leave out log text, thread pool sizes, class and method names as behavior, and anything observable only in a debugger; a race goes in as a behavior flagged `Looks unintended` with the interleaving.
7. Order check sequences as the code runs them when the order changes the outcome.

After the list:

- **Unreachable:** code in these files with no caller or no effect nobody would expect, with `path:line`.
- **Not behavior:** wiring, logging, and infrastructure you read and left out, one line each.
- **Secrets seen:** configuration keys whose values look like credentials, by key name only.
- **Capability boundary:** anything you read that belongs to another capability, or behavior of this capability you found outside the start files, with `path:line`. Say plainly if the capability as drawn looks wrong (it should be split, merged, or renamed).
