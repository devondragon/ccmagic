# finish-ticket error handling

| Situation | Action |
|-----------|--------|
| No tracker available, unless the prompt-relay detection rule matched (contract §7) | Stop. Tell user to install one or set `tracker:` in `.claude/ccmagic.local.md`. |
| No PR found | Stop. Tell user to create one first. |
| Ticket not found | Stop. Tell user the ID that failed. |
| Tracker MCP/CLI not connected | Stop. Tell user which integration is needed. |
| CI checks failing | Surface them. Ask user to fix or override. (Autonomous: `needs-human`; do not merge.) |
| Changes requested on PR | Surface them. Ask user to address or override. (Autonomous: `needs-human`; do not merge.) |
| PR has conflicts | Attempt local resolution. Escalate unresolvable conflicts to user. (Autonomous: trivial → resolve; business-logic → `needs-human`.) |
| Merge fails for other reason | Show the error. Do not retry blindly. |
| `--delete-branch` fails (branch checked out in a worktree, or any local-checkout reason) | Verify the merge succeeded (`gh pr view --json state`), delete the remote branch best-effort (`git push origin --delete {headRefName}`), leave the local checkout alone, and report the outcome gracefully; this is not an error. |
| Conflict resolution: `git checkout {headRefName}` fails with "'{headRefName}' is already used by worktree at '{path}'" | The branch lives in a linked worktree: run the same conflict-resolution commands from that worktree path instead, then re-attempt the merge. Not an error. |
| Target transition not found (JIRA/Linear) | Show available transitions/states. Ask user to pick. (Autonomous: for the Done target, try the fallbacks; if none match, apply `needs_human_label` and note it.) |
| QA label missing (GitHub QA path) | Ask user which label, offer to save to config. |
| Ticket update fails | Warn user. Report what was and wasn't updated. Continue to Done. |
| Cannot identify QA person (QA path only) | Ask the user directly. |
| User says "no" at confirmation | Stop cleanly. Nothing has been merged yet. |
| Autonomous: merge gate not satisfied | `needs-human`: route-and-stop (park to `needs_human_state`, comment on PR + ticket) if top-level; else emit the handshake for the parent. |
| `merge_owner: reeve` and `merge_handoff_state` does not exist on the team | Do not merge, do not transition. Interactive: say so and stop. Autonomous: `needs-human` with the state name in `reason`. |
