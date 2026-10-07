# Evidence file format: `docs/openspec-baseline.md`

`bin/ccm-baseline-check` parses this file. Its header comment states the same rules; keep the two in step. Anything not covered here is free prose and is not checked, except that every backticked `path:N` anywhere in the file must resolve and no em or en dash may appear.

## Layout

```markdown
# OpenSpec baseline evidence

Repository: <owner/name>. Baseline commit: <40-hex SHA>. Written <YYYY-MM-DD> by /ccmagic:spec-baseline, OpenSpec CLI <version>.

How to read this file. Each `### Requirement:` heading below matches a heading in `openspec/specs/<capability>/spec.md`. Under it, every scenario names the code that produces the behavior (`path:line` or `path:line-line`, relative to the repository root, at the baseline commit) and the test that pins it, or `UNTESTED`. Flags: `Looks unintended` (behavior the spec states as it is that a maintainer would probably not have chosen; the spec never describes a fix), `Open question` (the code does not settle it), `Docs disagree` (the repository's docs say something else), `Config` (the governing key and its value per profile or environment), `Security` (where a reviewer should look). Line numbers go stale as the code moves; `/ccmagic:spec-baseline --check` reports each citation whose lines changed after the baseline commit.

## 1. Capability map

| Capability | Observable purpose | Implementing files | Tests | Status |
|---|---|---|---|---|
| <name> | <one line, observable behavior> | `<path>`, ... | `<test file or class>`, ... or none | specified, N requirements |
| <name> | ... | ... | ... | mapped, about N requirements |
| <neighbor> | ... | ... | ... | not yet specified |

### Not specified

- <item>: <one-line reason (cross-cutting wiring, unreachable code, log-only behavior, deployment files)>
- <neighbor> (not yet specified), left out of <capability>:
  - <behavior>, `path:N`

### Secrets in configuration

<Which configuration keys hold credentials, by key name only, or "None found.">

## 2. <capability>

Baseline commit: <40-hex SHA>
Path key: `Key` is `path/to/File.ext`, `Other` is `path/to/dir`.

### Requirement: <exact requirement name from the spec>
- Scenario: <exact scenario name>. Code: `path:N`, `path:N-M` (what it shows), `:K`. Tests: `path/to/test.file::test title`, `TestClass.method` | UNTESTED.
- Scenario: <next scenario>. Config `some.key`: `config/app.yml:12` (value). Code: `Key:40-52`. Tests: UNTESTED (`OtherTest.method` covers only the happy path).
- Looks unintended: <statement with citations>.
- Open question: <question>.
- Docs disagree: `README.md:40` says <...>; the code <...>.
- Config: `some.key` is <value> in <environment> (`config/app-prd.yml:3`).
- Security: <where to look, with citations; never a secret value>.

### Left out of the spec on purpose
- <behavior of this capability that is not in the spec, and why, or where it is specified instead>
```

## Map and subsections

- **Status.** Each map row is `specified, N requirements` (its spec is written), `mapped, about N requirements` (accepted at Stop 1, not specified yet), or `not yet specified` (a neighbor named in a `--capability` run so that behavior left out of the specified capability has somewhere to go).
- **Every mode writes both subsections.** `### Not specified` and `### Secrets in configuration` are part of the header in a full run and in a `--capability` run alike, and each holds `None found.` when it has nothing.
- **Behavior left to another capability.** A behavior is left out of a capability as another's only when that capability has a map row. When that capability has no spec yet, the behavior is listed under its name in `### Not specified`, one nested line per behavior with a citation, so it reaches a spec when that capability is specified.

## Rules the checker enforces

- **Header.** Before the first `## ` heading there is a line holding `Baseline commit: <40-hex SHA>`: the commit, clean, at which the citations were written (the skill records `git rev-parse HEAD` in Step 1, when the tree is clean).
- **Sections.** `## N. <capability>` with a kebab-case name opens a capability's section and must match a folder `openspec/specs/<capability>/`. Every spec needs a section. `## 1. Capability map` and any other `## ` heading whose title is not kebab-case is prose.
- **Section baseline.** A section written at a later commit than the header's (a `--capability` run on a repository that already has a baseline) carries its own `Baseline commit: <40-hex SHA>` line before its first `### ` heading. `--check` measures that section's citations from it.
- **Path key.** An optional line starting `Path key` before the first `### ` heading declares short names, each written `` `Key` is `path` ``. A citation whose first path segment is a key has that segment replaced by the key's path: with `` `Api` is `src/api` ``, `` `Api/users.ts:10` `` is `src/api/users.ts:10`; with `` `Users` is `src/api/users.ts` ``, `` `Users:10` `` is the same line. A key applies only in its own section.
- **Requirement headings.** One `### Requirement: <name>` per requirement in the spec, the name copied exactly. No heading for a requirement the spec does not have. Any other `### ` heading ends the requirement.
- **Scenario lines.** Under each requirement heading, one line per scenario of that requirement in the spec, starting `- Scenario: <exact name>. `; the name ends at the first period followed by a space, so a name never contains ". ". The rest of the line must hold at least one citation and a `Tests:` field.
- **Citations.** A backticked `path:N` or `path:N-M`, the path relative to the repository root (or through a path key), N at least 1, M not before N, and both within the file in the working tree. A bare `` `:N` `` continues the path of the last citation on the same line. A backticked token is read as a citation only when its path holds a `/`, holds a `.` followed by a letter, or starts with a path key, so a host and port such as `localhost:8080` is not one; write a root file with no extension as `` `./Makefile:12` ``. A `path/file.ext:N` outside backticks is a finding: shorthand that cannot be checked is what makes a citation unverifiable later.
- **Tests field.** The text after `Tests:` names at least one test reference or holds `UNTESTED`. Each backticked test reference there must resolve:
  - `` `path/to/file::name` ``: the file is in the repository and contains `name` as written (a JS or TS test title, a pytest or Go test function name).
  - `` `Symbol.member` ``: some file whose name without its extension is `Symbol` (outside `openspec/`) contains `member` as a whole word (JUnit, xUnit, a Python test class).
  Other backticked text in the field (a cookie name, a header) is ignored.
- **Uniqueness.** Requirement names are unique within a spec, scenario names unique within a requirement, and the evidence repeats no heading or scenario line.
- **Spec shape.** Requirement and scenario names hold no backtick, `@`, `<`, `>`, `&`, URL, or trailing punctuation; requirement bodies and scenario lines hold no backtick, `@`, `<`, `>`, or `&` (Reeve rewrites them in ticket bodies); a requirement body is under 500 bytes; a requirement has fewer than 5 scenarios; `## Purpose` is present and at least 50 characters.
- **Project context.** `openspec/config.yaml` exists and has a top-level `context:` block.
- **Personal identifiers.** No email address in a spec or this file, written as `user@domain.tld` or spelled as `<word> at <domain>.<tld>` (case-insensitive; the domain must end in a common TLD: com, net, org, edu, gov, io, co, us, uk, de, fr, ca, au, info, biz, dev, app, me). Ordinary prose ("at the edge", "at most 4", "looked at config.yaml") is not flagged. Limits: a hostname after a word and "at" is flagged and is reworded; an address spelled with brackets or "dot" is not seen; phone numbers and account identifiers are not checked. Name the constant or config key, or write "a hard-coded personal address".
- **Dashes.** No em or en dash in a spec, `openspec/config.yaml`, or this file.
- **Changed paths.** Nothing outside `openspec/` and `docs/openspec-baseline.md` differs from the base (the merge base of HEAD with the default branch, or `--base REF`), and no untracked file outside them exists. Not checked under `--stale`.

Every rule is a finding and makes the exit 1; the checker has no warning level.

## What `--check` adds

With `--stale`, `bin/ccm-baseline-check` diffs each cited file from its section's baseline commit to HEAD. A citation is stale when a later commit replaced or removed one of its lines, inserted lines inside its range, deleted the file, or the file was not at the baseline commit at all. The output groups stale citations by capability and requirement and names the commits that touched each file. Each stale citation carries `kind` (`scenario`, `flag`, or `prose`), `scenario` (the scenario name, or null), and `flag` (the label of a flag line such as `Looks unintended` or `Config`, or null). The changed-paths rule is skipped, since code commits after the baseline are expected. A stale citation does not mean the spec is wrong, only that someone should look.
