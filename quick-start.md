---
allowed-tools: Write(*), Read(*), Bash(git:*), Bash(mkdir:*), Bash(touch:*), TodoWrite(*)
description: Fast-track feature setup - creates structure and starts work
argument-hint: "[feature-name]"
model: sonnet
---

# Quick Start - Rapid Feature Setup

Streamline feature creation by combining initialization, planning, and task startup into one command. Perfect for getting started quickly without manual setup.

## Quick Start Process

This command performs multiple steps automatically:
1. ✅ Verifies CCMagic is initialized (runs init if needed)
2. 📋 Creates feature structure
3. 📝 Generates initial task
4. 🌿 Creates feature branch
5. 🚀 Starts work immediately

## Usage

```bash
/ccmagic:quick-start [feature-name]
```

**Arguments**:
- `feature-name`: Kebab-case name for your feature (e.g., `user-authentication`, `payment-processing`)

## Implementation

### Step 1: Check if CCMagic is Initialized

```bash
# Check for context directory
if [ ! -d "context" ]; then
  echo "⚠️  CCMagic not initialized. Running init first..."
  # Trigger /ccmagic:init
else
  echo "✅ CCMagic already initialized"
fi
```

### Step 2: Parse Feature Name

Extract feature name from arguments:
```bash
FEATURE_NAME="$ARGUMENTS"

# Validate feature name
if [ -z "$FEATURE_NAME" ]; then
  echo "❌ Error: Feature name required"
  echo "Usage: /ccmagic:quick-start [feature-name]"
  exit 1
fi

# Convert to kebab-case if needed
FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')
echo "📦 Feature name: $FEATURE_NAME"
```

### Step 3: Determine Feature ID

Find the next available feature ID:

Read `context/working-state.md` to determine current epic (default to 001).

```bash
# Count existing features to get next ID
FEATURE_COUNT=$(ls -d context/features/*/ 2>/dev/null | wc -l)
NEXT_FEATURE=$(printf "%02d" $((FEATURE_COUNT + 1)))

# Assuming epic 001 (can be made configurable)
EPIC_ID="001"
FEATURE_ID="${EPIC_ID}-${NEXT_FEATURE}"
FULL_FEATURE_NAME="${FEATURE_ID}-${FEATURE_NAME}"

echo "🎯 Feature ID: $FULL_FEATURE_NAME"
```

### Step 4: Create Feature Directory Structure

```bash
# Create feature directories
mkdir -p "context/features/${FULL_FEATURE_NAME}"
mkdir -p "context/features/${FULL_FEATURE_NAME}/tasks/todo"
mkdir -p "context/features/${FULL_FEATURE_NAME}/tasks/current"
mkdir -p "context/features/${FULL_FEATURE_NAME}/tasks/completed"

echo "✅ Created feature directory structure"
```

### Step 5: Create Feature Overview

Create `context/features/${FULL_FEATURE_NAME}/overview.md`:

```markdown
# Feature: ${FEATURE_NAME}

## Parent Epic
${EPIC_ID}: [Epic name from context/epics/${EPIC_ID}-*.md]

## Feature ID
${FULL_FEATURE_NAME}

## Feature Scope
[Auto-generated description - update as needed]

This feature implements ${FEATURE_NAME} functionality.

## Goals
- [ ] Define specific goals for this feature
- [ ] Identify success criteria
- [ ] Determine acceptance requirements

## Architecture Decisions
[Document key technical decisions here]

## Task Summary
- Total tasks: 1 (initial setup)
- Completed: 0
- In Progress: 0
- Todo: 1

## Dependencies
- Project setup complete
- CCMagic initialized

## Notes
Created via quick-start command on [date]
```

### Step 6: Create Feature Working State

Create `context/features/${FULL_FEATURE_NAME}/working-state.md`:

```markdown
# Feature: ${FEATURE_NAME} - Working State

## Feature Status
- **Started**: [Today's date]
- **Target Completion**: TBD
- **Owner**: [From git config user.name]
- **Feature ID**: ${FULL_FEATURE_NAME}

## Task Progress

### In Progress
- [ ] None yet

### Ready to Start
- [ ] ${FULL_FEATURE_NAME}-001-initial-implementation

### Completed
- [ ] None yet

## Current Focus
Setting up feature structure and preparing for initial implementation.

## Decisions Log
- [Date]: Created feature via quick-start command
- [Date]: Initial task generated automatically

## Blockers
None

## Next Steps
1. Review and update feature scope in overview.md
2. Start initial implementation task
3. Define additional tasks as needed

## Next Sync
[Date/Time]
```

### Step 7: Create Initial Task

Create `context/features/${FULL_FEATURE_NAME}/tasks/todo/${FULL_FEATURE_NAME}-001-initial-implementation.md`:

```markdown
# Task ${FULL_FEATURE_NAME}-001: Initial Implementation

## Parent Epic
${EPIC_ID}: [Epic name]

## Parent Feature
${FULL_FEATURE_NAME}: ${FEATURE_NAME}

## Description
Implement the core functionality for ${FEATURE_NAME}.

This task covers:
- Setting up necessary files and structure
- Implementing basic feature functionality
- Adding initial tests
- Documenting the implementation

## Acceptance Criteria
- [ ] Core functionality implemented
- [ ] Unit tests added and passing
- [ ] Integration with existing system verified
- [ ] Documentation updated
- [ ] Code reviewed and approved

## Technical Details

### Files to Create/Modify
[TBD - update based on project structure]

### Implementation Approach
1. Analyze requirements
2. Design solution
3. Implement core logic
4. Add tests
5. Integration testing
6. Documentation

### Testing Strategy
- Unit tests for core logic
- Integration tests for system interaction
- Manual testing for user-facing features

## Estimated Time
4-8 hours (adjust based on complexity)

## Notes
- This is an auto-generated initial task
- Break down into smaller tasks if needed
- Update acceptance criteria as requirements clarify

## Dependencies
- Feature structure created
- Development environment ready

## Related Tasks
[Add related tasks as they are created]
```

### Step 8: Read Branching Configuration

Read `context/branching.md` to determine branching strategy:

```markdown
# Read branching.md to get:
- Strategy (A: Hierarchical, B: Direct, C: Single)
- Base branch (main/develop/master)
```

### Step 9: Create Feature Branch

Based on branching strategy from `context/branching.md`:

```bash
# Read base branch from branching.md
BASE_BRANCH=$(grep "Primary Branch" context/branching.md | awk '{print $NF}')

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Ensure we're on base branch
if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  echo "📍 Switching to $BASE_BRANCH"
  git checkout "$BASE_BRANCH"
  git pull origin "$BASE_BRANCH"
fi

# Create feature branch
BRANCH_NAME="feature/${FULL_FEATURE_NAME}"
git checkout -b "$BRANCH_NAME"

echo "✅ Created and switched to branch: $BRANCH_NAME"
```

### Step 10: Move Task to Current and Start Work

```bash
# Move task from todo to current
mv "context/features/${FULL_FEATURE_NAME}/tasks/todo/${FULL_FEATURE_NAME}-001-initial-implementation.md" \
   "context/features/${FULL_FEATURE_NAME}/tasks/current/"

echo "✅ Moved task to current/"
```

### Step 11: Update Working State

Update `context/working-state.md`:

```markdown
# Working State

## Current Focus
- **Epic**: ${EPIC_ID}
- **Feature**: ${FULL_FEATURE_NAME} (${FEATURE_NAME})
- **Task**: ${FULL_FEATURE_NAME}-001-initial-implementation
- **Last Updated**: [Today's date and time]

## Active Work Hierarchy

### Current Epic
**ID**: ${EPIC_ID}
**Name**: [From epic file]
**Status**: In Progress

### Current Feature
**ID**: ${FULL_FEATURE_NAME}
**Name**: ${FEATURE_NAME}
**Parent Epic**: ${EPIC_ID}
**Status**: In Progress
**Branch**: feature/${FULL_FEATURE_NAME}

### Current Task
**ID**: ${FULL_FEATURE_NAME}-001-initial-implementation
**Name**: Initial Implementation
**Parent Feature**: ${FULL_FEATURE_NAME}
**Branch**: feature/${FULL_FEATURE_NAME}
**Started**: [Today's date and time]
**Status**: In Progress

### Progress
- [x] Feature structure created
- [x] Initial task generated
- [x] Branch created
- [ ] Core implementation
- [ ] Tests added
- [ ] Documentation updated

## Key Decisions
- Using quick-start to accelerate feature setup
- Starting with single initial task, will break down further as needed

## Environment Setup
- [x] CCMagic initialized
- [x] Feature structure created
- [x] Git branch ready

## Next Steps
1. Review feature scope in context/features/${FULL_FEATURE_NAME}/overview.md
2. Implement core functionality
3. Add tests
4. Update documentation
```

### Step 12: Create Initial Commit

```bash
# Stage all new files
git add context/features/${FULL_FEATURE_NAME}/
git add context/working-state.md

# Create initial commit
git commit -m "feat: initialize ${FEATURE_NAME} feature structure

- Created feature ${FULL_FEATURE_NAME}
- Generated initial implementation task
- Updated working state
- Ready to begin development"

echo "✅ Created initial commit"
```

## Success Output

Display summary of what was created:

```markdown
# 🚀 Quick Start Complete!

## Feature Created
**ID**: ${FULL_FEATURE_NAME}
**Name**: ${FEATURE_NAME}
**Epic**: ${EPIC_ID}

## Structure Created
✅ Feature directory: `context/features/${FULL_FEATURE_NAME}/`
✅ Feature overview: `overview.md`
✅ Feature working state: `working-state.md`
✅ Task directories: `tasks/todo/`, `tasks/current/`, `tasks/completed/`
✅ Initial task: `${FULL_FEATURE_NAME}-001-initial-implementation.md`

## Git Status
✅ Branch created: `feature/${FULL_FEATURE_NAME}`
✅ Initial commit: "feat: initialize ${FEATURE_NAME} feature structure"
✅ Ready to push to remote

## Current Task
📋 **${FULL_FEATURE_NAME}-001-initial-implementation**
   Location: `context/features/${FULL_FEATURE_NAME}/tasks/current/`

## Next Steps
1. **Review scope**: Check `context/features/${FULL_FEATURE_NAME}/overview.md`
2. **Read task**: Review `context/features/${FULL_FEATURE_NAME}/tasks/current/${FULL_FEATURE_NAME}-001-initial-implementation.md`
3. **Start coding**: Begin implementing the feature
4. **Save progress**: Use `/ccmagic:checkpoint` regularly
5. **Complete task**: Run `/ccmagic:complete-task ${FULL_FEATURE_NAME}-001-initial-implementation` when done

## Useful Commands
- Check status: `/ccmagic:status`
- View current task: `/ccmagic:current-task`
- View current feature: `/ccmagic:current-feature`
- Save progress: `/ccmagic:checkpoint`
- Run tests: `/ccmagic:test`

---
**You're all set!** Start implementing ${FEATURE_NAME} 🎉
```

## Error Handling

### Feature Already Exists
```markdown
❌ Error: Feature ${FULL_FEATURE_NAME} already exists.

Existing features:
[List of existing features with same name]

Options:
1. Use different feature name
2. Continue with existing feature using `/ccmagic:start-task`
3. Delete existing feature if created by mistake
```

### Invalid Feature Name
```markdown
❌ Error: Invalid feature name

Feature names must:
- Use kebab-case (lowercase with hyphens)
- Contain only letters, numbers, and hyphens
- Be descriptive but concise

Examples:
✅ user-authentication
✅ payment-processing
✅ api-integration
❌ User Authentication
❌ user_authentication
❌ userAuth
```

### Not a Git Repository
**Error Message:**
```
❌ Error: Not a git repository

Quick start requires git for branching.
```

**Solution:**

Initialize git first:
```bash
git init
git add .
git commit -m "Initial commit"
```

Then run quick-start again.

## Advanced Options

### Custom Epic
Allow specifying epic ID:
```bash
/ccmagic:quick-start user-auth --epic 002
```

### Skip Branch Creation
For single-branch workflow:
```bash
/ccmagic:quick-start user-auth --no-branch
```

### With Template
Start from predefined template:
```bash
/ccmagic:quick-start user-auth --template authentication
```

## Pro Tips

1. **Name Carefully**: Feature names become branch names and task IDs
2. **Review Immediately**: Check generated files and update descriptions
3. **Break Down**: Initial task is broad - break into smaller tasks as needed
4. **Commit Often**: Use checkpoints to save progress frequently
5. **Update Scope**: Refine feature overview.md as understanding grows

---

Quick start makes it easy to jump into development without manual setup. Perfect for rapid prototyping and getting started fast!
