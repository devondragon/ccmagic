# Context Load Command

Resume a previously saved conversation context, restoring project understanding, decisions, and work progress.

## Context Loading Process

1. **Locate Context**: Find saved context by ID or latest
2. **Validate Context**: Ensure context matches current project state
3. **Load Information**: Restore conversation history and decisions
4. **Sync State**: Align with current branch and changes
5. **Resume Work**: Continue from where previous session ended

## Implementation

### 1. Context Discovery

```bash
# List available contexts
ls -la .claude/contexts/

# Find latest context for current branch
CURRENT_BRANCH=$(git branch --show-current)
LATEST_CONTEXT=$(ls -t .claude/contexts/ | grep $CURRENT_BRANCH | head -1)

# Or specify context ID
CONTEXT_ID=${1:-$LATEST_CONTEXT}
```

### 2. Load and Validate Context

```bash
# Check if context exists
if [ ! -d ".claude/contexts/$CONTEXT_ID" ]; then
  echo "Context not found. Available contexts:"
  ls .claude/contexts/
  exit 1
fi

# Load metadata
METADATA=$(cat .claude/contexts/$CONTEXT_ID/metadata.json)

# Validate branch match
SAVED_BRANCH=$(echo $METADATA | jq -r '.git.branch')
if [ "$SAVED_BRANCH" != "$CURRENT_BRANCH" ]; then
  echo "⚠️ Context is for branch: $SAVED_BRANCH"
  echo "Current branch: $CURRENT_BRANCH"
  echo "Switch branches or load different context"
fi
```

### 3. Context Loading Report

```markdown
# Context Loaded Successfully ✅

## Context Information
- **ID**: project-feature-auth-20240115T143022Z
- **Saved**: 2024-01-15 14:30:22 UTC (2 hours ago)
- **Branch**: feature/user-auth
- **Task**: TASK-123 - Implement user authentication

## Session Summary
You were working on implementing user authentication with JWT tokens and OAuth2 integration.

### Progress Status
- ✅ Auth service created
- ✅ JWT implementation complete
- ✅ OAuth2 (Google, GitHub) integrated
- 🔄 Password reset flow (75% complete)
- 📋 Email verification pending

## Key Decisions Restored
1. Using JWT with refresh token rotation
2. bcrypt for password hashing (12 rounds)
3. Passport.js for OAuth strategies
4. Rate limiting on auth endpoints

## Code Locations
- Auth service: `src/services/auth.service.ts`
- JWT utilities: `src/utils/jwt.ts`
- OAuth handlers: `src/auth/oauth/`
- Tests: `tests/auth.test.ts`

## State Comparison

### Since Context Save:
- **New commits**: 2
  - abc456: Update error handling
  - def789: Add logging middleware
- **Files changed**: 5
- **Tests status**: Still passing ✅

## Active Todos
1. Complete password reset email sending
2. Implement reset confirmation endpoint
3. Add email verification system
4. Setup MFA support

## Recommended Next Steps
1. Continue with password reset flow
2. Run `/status.md` to see current state
3. Run `/sync.md` if needed to update with main

## Important Notes
- Rate limiting was set to 5 requests per minute
- OAuth callbacks configured for localhost:3000
- Email service credentials needed for reset flow
```

### 4. Restore Working Context

```python
def load_context(context_id):
    """Load and restore a saved context"""
    
    # Load all context files
    metadata = load_json(f".claude/contexts/{context_id}/metadata.json")
    conversation = load_file(f".claude/contexts/{context_id}/conversation.md")
    state = load_file(f".claude/contexts/{context_id}/project-state.md")
    decisions = load_file(f".claude/contexts/{context_id}/decisions.md")
    code_map = load_file(f".claude/contexts/{context_id}/code-map.md")
    todos = load_file(f".claude/contexts/{context_id}/todos.md")
    
    # Create restoration summary
    summary = {
        "context_age": calculate_age(metadata["timestamp"]),
        "branch_match": metadata["git"]["branch"] == current_branch(),
        "changes_since": get_changes_since(metadata["git"]["commit"]),
        "todos_remaining": parse_remaining_todos(todos),
        "key_files": extract_key_files(code_map)
    }
    
    return summary
```

### 5. Smart Context Merge

When loading context on a changed codebase:

```markdown
## Context Merge Analysis

### Files Changed Since Save
1. `src/services/auth.service.ts`
   - Context knows: Basic auth implementation
   - Current state: Added error handling
   - Action: Review new error handling code

2. `src/middleware/logger.ts` (NEW)
   - Context knows: Nothing
   - Current state: New logging middleware
   - Action: Analyze new file purpose

### Decisions to Revisit
- Password hashing rounds (12 → consider 14)
- Rate limiting (5/min → team suggests 10/min)

### Conflicts Detected
- Context expects: `src/utils/jwt.ts`
- Current state: Renamed to `src/utils/token.ts`
- Resolution: Update references to new filename
```

## Context Loading Strategies

### 1. Full Restoration
Load entire context as-is:
```bash
# Load everything
cat .claude/contexts/$CONTEXT_ID/conversation.md
cat .claude/contexts/$CONTEXT_ID/decisions.md
cat .claude/contexts/$CONTEXT_ID/code-map.md
```

### 2. Selective Loading
Load only specific parts:
```bash
# Just load decisions and code map
cat .claude/contexts/$CONTEXT_ID/decisions.md
cat .claude/contexts/$CONTEXT_ID/code-map.md
```

### 3. Merge with Current
Combine saved context with current state:
```bash
# Show what's changed
git diff $(cat .claude/contexts/$CONTEXT_ID/metadata.json | jq -r .git.commit) HEAD

# Merge todos with current task list
```

## Multi-Context Management

### List All Contexts
```bash
# Show all saved contexts with details
for dir in .claude/contexts/*/; do
  metadata=$(cat $dir/metadata.json)
  echo "ID: $(basename $dir)"
  echo "Branch: $(echo $metadata | jq -r .git.branch)"
  echo "Task: $(echo $metadata | jq -r .task.title)"
  echo "Saved: $(echo $metadata | jq -r .timestamp)"
  echo "---"
done
```

### Search Contexts
```bash
# Find contexts by branch
find .claude/contexts -name "metadata.json" \
  -exec grep -l "feature/user-auth" {} \;

# Find contexts by task
grep -r "TASK-123" .claude/contexts/
```

### Clean Old Contexts
```bash
# Remove contexts older than 30 days
find .claude/contexts -type d -mtime +30 -exec rm -rf {} \;

# Archive old contexts
tar -czf .claude/archived-contexts.tar.gz \
  .claude/contexts/*/
```

## Team Context Sharing

### Import Team Member's Context
```bash
# Download shared context
curl -o context.tar.gz https://team-share/contexts/context-id.tar.gz

# Extract to contexts directory
tar -xzf context.tar.gz -C .claude/contexts/

# Load the context
/context-load context-id
```

### Context Handoff Protocol
```markdown
## Handoff Information

### From: Alice
### To: Bob
### Context: project-feature-auth-20240115T143022Z

## Summary
Alice completed 75% of authentication implementation.
Needs completion of password reset and email verification.

## Critical Information
- OAuth tokens stored in `.env.local`
- Test user: test@example.com / password123
- Staging server: https://staging.app.com

## Blockers
- Email service API key needed
- Waiting for security review on password policy

## Ready for Handoff
Bob can continue with:
1. Complete password reset flow
2. Implement email verification
3. Add MFA support
```

## Error Recovery

### Context Corruption
```bash
# Validate context files
if ! jq empty .claude/contexts/$CONTEXT_ID/metadata.json 2>/dev/null; then
  echo "Metadata corrupted, attempting recovery..."
  # Try to restore from backup
fi
```

### Mismatched State
```bash
# When context doesn't match current state
echo "Context mismatch detected. Options:"
echo "1. Switch to context branch: git checkout $SAVED_BRANCH"
echo "2. Load anyway and merge changes"
echo "3. Create new context from current state"
```

## Integration with Other Commands

- Automatically load latest context on `/init.md`
- Save before load to preserve current state
- Use with `/handoff.md` for team transitions
- Update `/status.md` with loaded context info

## Execution

Load context immediately. If no context ID provided, load latest for current branch. Display comprehensive summary of restored context. Highlight any conflicts or changes since save. Provide clear next steps to resume work. Ensure smooth continuation of interrupted work.