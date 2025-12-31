---
allowed-tools: Write(*), Read(*), Bash(git:*), LS(*), Glob(*), Task(*), TodoWrite(*)
description: Create detailed handoff documentation for context switching
argument-hint: [next-developer-name or 'general']
model: sonnet
---

# Create Handoff Documentation

I'll create comprehensive handoff documentation to ensure smooth context transfer.

> **Parallel execution:** When operations are independent, run them simultaneously—exploring different code areas, reading unrelated files, or gathering context from multiple sources. Claude Code will determine when this is safe and helpful.

## Efficient Context Gathering with Explore Agent

For comprehensive handoffs, use the Task tool with Explore agent to gather context in parallel:

```
Use Task tool with:
  subagent_type: "Explore"
  prompt: "Gather handoff context for this project. Analyze:
          1. Current working state and active tasks
          2. Recent code changes and their purpose
          3. Known issues, blockers, and TODOs in code
          4. Dependencies and integration points
          5. Test status and coverage
          Provide a comprehensive summary suitable for handoff."
```

This parallelizes context gathering and produces a focused summary.

## Alternative: Manual Gathering (if Explore agent unavailable)

## Gathering Current State...

### 1. Reading Project Context:
First, let me check the current project state and identify active work:

```bash
# Check if context directory exists
if [ ! -d "context" ]; then
    echo "❌ No context directory found. Please run /ccmagic:init first."
    exit 1
fi

# Check current git branch and status
git branch --show-current
git status --short
```

Loading project files:
- `context/project.md` - Project overview
- `context/working-state.md` - Current status
- `context/conventions.md` - Team standards

### 2. Identifying Active Work:

Reading current task and feature state:
- Checking `context/working-state.md` for current epic/feature/task
- Looking for active tasks in `context/features/*/tasks/current/`
- Checking feature-specific working states

```bash
# Find current task
find context/features/*/tasks/current -name "*.md" -type f 2>/dev/null | head -1
```

### 3. Analyzing Recent Activity:

```bash
# Get recent commits (last 10)
echo "📝 Recent Commits:"
git log --oneline -10

# Show uncommitted changes
echo "📊 Uncommitted Changes:"
git status --porcelain

# Check for stashed work
echo "📦 Stashed Work:"
git stash list
```

### 4. Reading Task Progress:

If a current task exists, loading:
- Task description and acceptance criteria
- Progress against acceptance criteria
- Time spent and estimates
- Any blockers or issues

### 5. Checking Test and Build Status:

```bash
# Check if tests are configured and their last status
if [ -f "package.json" ]; then
    # For Node.js projects
    echo "🧪 Test Status:"
    npm test --silent 2>/dev/null && echo "✅ Tests passing" || echo "❌ Tests failing or not configured"
elif [ -f "Cargo.toml" ]; then
    # For Rust projects
    cargo test --quiet 2>/dev/null && echo "✅ Tests passing" || echo "❌ Tests failing"
elif [ -f "go.mod" ]; then
    # For Go projects
    go test ./... 2>/dev/null && echo "✅ Tests passing" || echo "❌ Tests failing"
fi
```

## Creating Handoff Document

Based on the gathered information, I'll create a detailed handoff document.

### Determining Handoff Type:
$ARGUMENTS

Creating handoff document at: `context/sessions/handoffs/YYYY-MM-DD-HH-MM-handoff-{recipient}.md`

```markdown
# Handoff Documentation
**Date**: [Current timestamp]
**From**: [Current developer - from git config]
**To**: [Recipient name or "Next Developer"]
**Branch**: [Current branch name]

## 📍 Current State

### Active Work
- **Epic**: [Current epic ID and name]
- **Feature**: [Current feature ID and name]
- **Task**: [Current task ID and name]
- **Progress**: [Percentage complete]
- **Time Spent**: [Hours/days on current task]

### Branch Status
- **Current Branch**: [Branch name]
- **Commits Ahead**: [Number] commits ahead of main
- **Last Commit**: [Time] ago - "[Commit message]"
- **Uncommitted Files**: [Count] files with changes

## ✅ Work Completed

### This Session
[List what was accomplished since last checkpoint/handoff]
- Implemented [specific features/functions]
- Fixed [bugs resolved]
- Updated [documentation/tests]
- Refactored [code improvements]

### Task Progress Detail
[For current task, show acceptance criteria status]
- [x] Criterion 1 - Complete
- [x] Criterion 2 - Complete
- [ ] Criterion 3 - In progress (75% done)
- [ ] Criterion 4 - Not started

## 🚧 Current Blockers

[List any blockers with context]
1. **[Blocker Title]**
   - Description: [What's blocking]
   - Impact: [What can't be done]
   - Workaround: [Temporary solution if any]
   - Who can help: [Person/team to resolve]

## 💡 Important Context

### Technical Decisions
[Recent decisions that affect implementation]
- Chose [Technology A] because [reasoning]
- Implemented [Pattern B] for [purpose]
- Avoided [Approach C] due to [constraints]

### Gotchas & Warnings
[Things that might trip up the next developer]
- ⚠️ [Warning about tricky code section]
- ⚠️ [Environment-specific configuration needed]
- ⚠️ [Known issue with workaround]

### Key Files Modified
[List with brief description of changes]
- `[filepath]` - [What was changed and why]
- `[filepath]` - [What was changed and why]

## 🎯 Immediate Next Steps

### To Continue Current Task:
1. [Specific next action with enough detail]
2. [Following action]
3. [And so on]

### Setup Required:
[Any setup the next developer needs]
```bash
# Commands to run
npm install  # If new dependencies added
npm run dev  # Start development server
```

### Recommended Workflow:
1. Pull latest changes: `git pull origin [branch]`
2. Review this handoff document
3. Check `context/working-state.md` for full context
4. Read current task file in `context/features/*/tasks/current/`
5. [Specific recommendations based on current state]

## 🤔 Open Questions

[Questions that need team input or decisions]
1. **[Question]**
   - Context: [Why this matters]
   - Options: [Possible approaches]
   - Recommendation: [Your suggestion if any]

## 📊 Metrics & Status

### Time Tracking
- **Session Duration**: [How long you worked]
- **Task Total Time**: [Total time on current task]
- **Estimated Remaining**: [Hours to complete task]
- **Feature Progress**: [X of Y tasks complete]

### Code Metrics
- **Files Changed**: [Count]
- **Lines Added**: +[Number]
- **Lines Removed**: -[Number]
- **Test Coverage**: [Percentage if available]

## 📝 Session Notes

### What Went Well
[Successes and smooth progress]

### Challenges Encountered
[Difficulties and how they were addressed]

### Learnings
[New discoveries, patterns, or insights]

## 🔗 References

### Related Documentation
- Architecture: `context/knowledge/architecture.md`
- Data Model: `context/knowledge/data-model.md`
- API Contracts: `context/knowledge/api-contracts.md`

### External Resources
- [Link to design mockups]
- [Link to API documentation]
- [Link to related tickets/issues]

## ✅ Handoff Checklist

Before handoff complete:
- [ ] All changes committed
- [ ] Branch pushed to remote
- [ ] Tests passing (or noted why not)
- [ ] Working state files updated
- [ ] This handoff document created
- [ ] Team notified (if applicable)

---

**Handoff Created**: [Timestamp]
**Next Sync**: [Suggested time for check-in]
```

## Updating Project State

### Updating `context/working-state.md`:
Adding reference to this handoff:
```markdown
## Last Handoff
- **Date**: [Timestamp]
- **Document**: `context/sessions/handoffs/[filename]`
- **To**: [Recipient]
- **Status**: [Brief status summary]
```

### For Feature Handoffs:
If handing off an entire feature, updating `context/features/[feature]/working-state.md`:
```markdown
## Handoff History
- [Date]: Handoff to [Developer] - See [handoff file]
```

## Final Steps

### Git Operations:
```bash
# Commit the handoff document
git add context/sessions/handoffs/
git add context/working-state.md
git commit -m "docs: Create handoff documentation for [recipient/purpose]

- Current task: [task-id] at [percentage]% complete
- Blockers: [count] documented
- Next steps defined"

# Push to remote
git push origin $(git branch --show-current)
```

### Summary Message:
```
📋 Handoff Documentation Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 Current Status:
   Task: [Task ID] - [Progress]%
   Branch: [Branch name]
   
📄 Handoff Document:
   context/sessions/handoffs/[filename]
   
🎯 Key Points:
   • [Main accomplishment]
   • [Main blocker if any]
   • [Critical next step]
   
✅ Ready for handoff to: [Recipient]

📌 Next developer should:
   1. Pull latest from [branch]
   2. Read handoff document
   3. Continue with [specific task/action]
   
💡 Remember to check for any merge conflicts
   if pulling from main before continuing work.
```

## Quick Handoff Option

For rapid handoffs (use with argument "quick"):
- Creates condensed version with essential info only
- Focuses on: current state, blockers, next steps
- Skips: detailed metrics, session notes, extensive context
- Good for: daily standups, quick team switches

## Best Practices

1. **Create handoffs regularly**: End of day, before breaks, when switching tasks
2. **Be specific**: Include exact commands, file paths, and next steps
3. **Document blockers clearly**: Include who can help resolve them
4. **Update before pushing**: Ensure handoff reflects latest changes
5. **Commit with the handoff**: Keep documentation in sync with code