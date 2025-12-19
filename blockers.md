---
allowed-tools: Read(*), Bash(git:*), Glob(*), Grep(*), Task(*), TodoWrite(*), Write(*)
description: Surface and track blockers across all features and tasks
model: claude-haiku-4-20250514
---

# Blockers Command

Surface, track, and manage blockers across all features and tasks. Provides a unified view of what's blocking progress and helps prioritize unblocking efforts.

## Implementation

### Step 1: Gather Blocker Information (PARALLEL)

Run these searches in parallel using multiple tool calls in a single message:

```
# PARALLEL - send all in ONE message:

Grep 1: Search for "blocker" or "blocked" in context files
  pattern: "(?i)(blocker|blocked|blocking)"
  path: "context/"

Grep 2: Search for TODO/FIXME with blocking implications
  pattern: "(?i)(TODO|FIXME).*(block|wait|need|depend)"

Grep 3: Search for HACK/WORKAROUND comments
  pattern: "(?i)(HACK|WORKAROUND|TEMP)"

Bash: Check for merge conflicts
  command: "git diff --name-only --diff-filter=U 2>/dev/null || echo 'none'"
```

### Step 2: Parse Context Files

Read and parse blocker sections from:
- `context/working-state.md` - Current blockers
- `context/features/*/working-state.md` - Feature-level blockers
- `context/features/*/tasks/current/*.md` - Task-level blockers
- `context/backlog.md` - Backlog items marked as blocked

### Step 3: Categorize and Prioritize

## Blocker Report Format

```markdown
# Blocker Report
**Generated**: [timestamp]
**Project**: [from context/project.md]

## Summary
- **Critical Blockers**: X (blocking production or release)
- **High Priority**: Y (blocking feature completion)
- **Medium Priority**: Z (blocking tasks)
- **Low Priority**: W (inconveniences, workarounds exist)

---

## Critical Blockers (Immediate Action Required)

### BLOCK-001: [Blocker Title]
**Severity**: Critical
**Blocking**: [What work is blocked]
**Owner**: [Who can resolve]
**Age**: [Days since identified]

**Description**:
[Detailed description of the blocker]

**Impact**:
- [ ] Feature X cannot be completed
- [ ] Release Y is delayed
- [ ] Team Z is idle

**Resolution Path**:
1. [Step to resolve]
2. [Next step]

**Workaround** (if any):
[Temporary solution being used]

---

## High Priority Blockers

### BLOCK-002: [Blocker Title]
**Severity**: High
**Blocking**: [What work is blocked]
**Source**: `context/features/001-02-auth/working-state.md`

[Details...]

---

## Medium Priority Blockers

### BLOCK-003: [Blocker Title]
**Severity**: Medium
**Blocking**: [Task or subtask]
**Source**: [File where identified]

[Details...]

---

## Low Priority / Workarounds Active

### BLOCK-004: [Blocker Title]
**Severity**: Low
**Workaround**: Active and acceptable
**Source**: [Code file with HACK/WORKAROUND comment]

[Details...]

---

## Code-Level Issues

### TODOs Blocking Progress
| File | Line | Comment | Priority |
|------|------|---------|----------|
| `src/auth.ts` | 45 | TODO: Need API key from ops | High |
| `src/db.ts` | 123 | FIXME: Waiting for schema change | Medium |

### Merge Conflicts
| File | Conflict With | Resolution Needed |
|------|---------------|-------------------|
| [none or list] | | |

### Failing Tests Blocking CI
| Test File | Failure | Since |
|-----------|---------|-------|
| [none or list] | | |

---

## Blocker Aging

### Stale Blockers (> 7 days)
These blockers may need escalation:
| Blocker | Age | Owner | Last Update |
|---------|-----|-------|-------------|
| BLOCK-001 | 12 days | @devops | 5 days ago |

### Recently Added (< 24 hours)
| Blocker | Added | By |
|---------|-------|-----|
| BLOCK-005 | 2 hours ago | @frontend |

---

## Recommended Actions

### Immediate (Today)
1. [ ] Escalate BLOCK-001 to @manager - 12 days old
2. [ ] Schedule meeting for BLOCK-002 resolution

### This Week
1. [ ] Follow up on API key request (BLOCK-003)
2. [ ] Review workaround for BLOCK-004

### Unblock Requests
Team members needed:
- **DevOps**: BLOCK-001 (API credentials)
- **Backend**: BLOCK-002 (Schema migration)
- **Design**: BLOCK-005 (Asset delivery)

---

## Quick Actions

Based on current blockers:
- `/ccmagic:handoff` - Document blockers for team handoff
- `/ccmagic:checkpoint` - Save current blocked state
- `/ccmagic:add-backlog` - Move blocked work to backlog
```

## Adding a New Blocker

When a blocker is identified, update the appropriate working-state.md:

```markdown
## Blockers
- **[BLOCK-ID]**: [Description]
  - Severity: [Critical/High/Medium/Low]
  - Blocking: [What's blocked]
  - Owner: [Who can resolve]
  - Added: [Date]
  - Workaround: [If any]
```

## Resolving Blockers

When a blocker is resolved:
1. Update working-state.md to remove or mark resolved
2. Add to "Decisions Log" if resolution involved a decision
3. Update any related task files
4. Run `/ccmagic:checkpoint` to record progress

## Integration with Other Commands

- **`/ccmagic:daily-standup`**: Blockers section uses this data
- **`/ccmagic:handoff`**: Includes blocker summary
- **`/ccmagic:status`**: Shows blocker count in health indicators
- **`/ccmagic:checkpoint`**: Records blocker state changes

## Execution

Generate blocker report immediately. Prioritize by severity and age. Highlight actionable items and responsible parties. Use TodoWrite to create a checklist of unblocking actions.
