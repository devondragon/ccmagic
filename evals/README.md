# ccmagic eval suite: `review`

Covers the `/ccmagic:review` skill only. Every case pastes a unified diff inline and states that no git checkout exists, so the skill has to review the supplied diff. Each case runs in two arms (with the plugin, without it) and the headline number is Δ = with-plugin score minus without-plugin score.

Run the full suite (3 runs per case, both arms, opus judge):

```
claude plugin eval . --ablation with-without --judge-model opus
```

Add `--no-publish` to keep the report local.

## Cases

| case | shape | expected routing | outcome graders (weight 1) | format graders (weight 0.5) | invariants |
|---|---|---|---|---|---|
| 01-quick-clean-log-fix | slash command, 1 file, comment + log reword | QUICK | llm: no CRITICAL/WARNING, verdict PASS | routing line QUICK, routing line matches script | |
| 02-quick-off-by-one | natural language, 1 file, `<=` loop bound | QUICK | llm: names the bound bug, effect, severity, fix | routing QUICK, routing line matches script, verdict not PASS | Edit never called |
| 03-deep-auth-path-small | slash command, 1 file in `src/auth/`, expiry check deleted | DEEP by risk path | llm: Critical/High on missing expiry, consequence, fix | routing DEEP, routing line matches script, confidence % present | Edit never called |
| 04-deep-sql-injection | natural language, 3 files, concatenated SQL | DEEP by size | llm: Critical injection, example payload, parameterized fix, ranked first | routing DEEP, routing line matches script, confidence % present | Edit never called |
| 05-quick-noise-bait | slash command, 2 files, cosmetic churn only | QUICK | llm: no CRITICAL/WARNING on imports, TODO, JSDoc, whitespace; verdict PASS | routing QUICK, routing line matches script | |
| 06-neg-explain-diff | "explain, no review" | must not fire | llm: short prose, no findings/verdict | | no `ccmagic:review` Skill call, no routing line |
| 07-neg-write-test | "write a Jest test" | must not fire | regex: Jest test block present | | no `ccmagic:review` Skill call, no routing line |

Fire cases also carry `review-fired`, a display-only `tool_used: Skill` check. It is reported, never scored. Note that a prompt beginning with `/ccmagic:review` is expanded by the harness without a Skill tool call, so that check reads 0 even when the skill ran; the routing-line regex is the trigger evidence for slash-command cases. The check is informative only for the natural-language cases (02, 04).

`routes-match-script` in cases 01 to 05 holds the exact routing line `bin/ccm-review-route --diff-file -` prints for that case's diff, so it passes only when the skill printed the script's decision instead of deriving its own. Those cases allow `Bash` so the skill can pipe the pasted diff to the script. `tests/run.sh` (`route_eval_cases_match_graders`) runs the script on each case's diff and checks the line against these graders and the expected route, so a change to the routing rules that moves a case shows up in the tests before an eval run.

## Side channels and ceilings

Measured on the 2026-09-18 pilots (1 run, both arms), with-plugin arm:

| case type | cost per run | wall time | ceiling |
|---|---|---|---|
| QUICK and negative cases | $0.05 to $0.15 | 5 to 64 s | $1.00, 300 s |
| DEEP cases | $0.10 to $0.20 | 30 to 103 s | $4.00, 900 s |

Pilot cost for 7 cases × 1 run × 2 arms: $1.36 and $1.74. A full suite at `runs: 3` is about $5.

Baseline on main at e87c906 (2026-09-18, 3 runs per arm): mean Δ +0.20, $4.77, 446 s at -j 4.

After the issue #37 fix (3 runs per arm, -j 4), case 05-quick-noise-bait scores with 1.00, without 0.00, Δ +1.00, with `no-noise-findings` passing 3/3 in the with-plugin arm (0/3 at the baseline).

After the issue #35 fix (full suite, 3 runs per arm, -j 4): mean Δ +0.25, $8.37, 764 s. Measured before 3.12.0 added Bash to cases 01 to 05 and the `routes-match-script` grader, so later runs are not directly comparable.

Known conditions of the without-plugin arm: the sandbox still has the built-in `/code-review` skill, and the model used it on several runs. The without arm is therefore "Claude with generic review tooling," not a bare model.

Known findings from the pilots, kept in the suite on purpose:

- Natural-language review requests (02, 04) now trigger the skill after the issue #35 description rewrite: `review-fired` in the with-plugin arm went from 0/3 to 3/3 on both cases across two full suite runs. The routing-line and confidence regex graders still read 0/3 on those cases because the skill runs under `context: fork` when reached through the Skill tool, and the parent summarizes the fork's report in its own words, dropping the routing line and confidence scores. Slash-command prompts are expanded inline by the harness, which is why 01, 03, and 05 match. Issue #35 stays open for that half; it is a `context: fork` design decision, not a wording problem.
- With the skill, the review reported "PASS WITH WARNINGS" on INFO-only findings in one run of 01, against its own verdict rule (issue #36; verdict rule made explicit in PR #38).
- With the skill, a removed JSDoc block was reported as a WARNING in 05, although the skill's finding rules exclude missing comments unless a convention requires them (issue #37; fixed in PR #38, case 05 with-arm 0.33 to 1.00).
- In DEEP mode with no repository present, the skill performed the analysis inline and dispatched no Explore agents, and said so in Coverage.
