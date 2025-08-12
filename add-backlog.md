# Add Backlog Command

Add new items to the product backlog with proper categorization, priority, and context.

## Backlog Item Creation

Capture new work items, feature requests, bugs, technical debt, and improvements in a structured backlog format.

## Implementation

### 1. Determine Item Type

Analyze the request to categorize:
- **Feature**: New functionality or capability
- **Bug**: Defect or issue to fix
- **Enhancement**: Improvement to existing functionality
- **Tech Debt**: Code refactoring or infrastructure improvement
- **Spike**: Research or investigation needed
- **Documentation**: Documentation updates needed

### 2. Extract Information

Parse the user's request to identify:
- Title/Summary
- Description/Details
- Acceptance Criteria
- Priority indicators
- Dependencies
- Estimated complexity

### 3. Generate Backlog Entry

Create structured backlog item with:
- Unique ID (auto-generated)
- Timestamp
- Category
- Priority
- Status (default: "backlog")

## Backlog Storage

### File Structure
```
.claude/
└── backlog/
    ├── backlog.json        # Main backlog data
    ├── features/           # Feature requests
    ├── bugs/              # Bug reports
    ├── tech-debt/         # Technical debt items
    └── archive/           # Completed/cancelled items
```

### Backlog Entry Format

```json
{
  "id": "BACKLOG-001",
  "created": "2024-01-15T14:30:22Z",
  "type": "feature",
  "priority": "high",
  "status": "backlog",
  "title": "Add user profile management",
  "description": "Users should be able to view and edit their profile information including avatar, bio, and preferences",
  "acceptance_criteria": [
    "User can view their current profile",
    "User can update profile fields",
    "Changes are persisted to database",
    "Profile updates trigger cache invalidation"
  ],
  "labels": ["user-facing", "mvp"],
  "estimated_effort": "L",
  "dependencies": ["auth-system"],
  "notes": "Consider GDPR compliance for profile data",
  "created_by": "current-session",
  "context": {
    "branch": "main",
    "session_id": "session-123"
  }
}
```

## Intelligent Parsing

### Example Input Processing

User says: "We need to fix the login timeout issue that's affecting mobile users"

Parsed as:
```json
{
  "type": "bug",
  "priority": "high",
  "title": "Fix login timeout issue on mobile",
  "description": "Mobile users experiencing login timeouts",
  "labels": ["mobile", "authentication", "production-issue"]
}
```

User says: "Add dark mode support"

Parsed as:
```json
{
  "type": "feature",
  "priority": "medium",
  "title": "Dark mode support",
  "description": "Implement dark mode theme option",
  "labels": ["ui", "user-preference"]
}
```

## Priority Assignment

### Automatic Priority Detection

Look for keywords to set priority:
- **Critical**: "urgent", "blocking", "down", "security"
- **High**: "important", "asap", "needed for release"
- **Medium**: "should have", "nice to have"
- **Low**: "someday", "when possible", "future"

### Priority Matrix

```
Impact ↑
High    | Medium  | High    | Critical
Medium  | Low     | Medium  | High
Low     | Low     | Low     | Medium
        Low      Medium    High    → Urgency
```

## Backlog Management

### Quick Add Format

For simple additions:
```
/ccmagic:add-backlog "Add password strength indicator"
```

### Detailed Add Format

For complex items:
```
/ccmagic:add-backlog
Type: feature
Title: Implement SSO with SAML
Priority: high
Description: Add SAML-based SSO for enterprise customers
Acceptance Criteria:
- Support SAML 2.0
- Work with Okta, Auth0, Azure AD
- Maintain existing auth for non-SSO users
Dependencies: auth-system, enterprise-tier
Effort: XL
```

## Backlog Operations

### View Backlog Summary
```bash
# Count items by type
cat .claude/backlog/backlog.json | jq 'group_by(.type) | map({type: .[0].type, count: length})'

# Show high priority items
cat .claude/backlog/backlog.json | jq '.[] | select(.priority == "high")'
```

### Generate Sprint Candidates
```markdown
## Ready for Sprint Planning

### High Priority (3 items)
1. BACKLOG-001: Fix login timeout on mobile [Bug]
2. BACKLOG-003: Add rate limiting to API [Security]
3. BACKLOG-007: Implement user search [Feature]

### Medium Priority (5 items)
...

### Quick Wins (2 items)
1. BACKLOG-012: Fix typo in error message [Bug, XS]
2. BACKLOG-015: Update README [Docs, S]
```

## Integration Points

### With Planning Commands
- `/ccmagic:plan` - Pull from backlog for planning
- `/ccmagic:create-tasks` - Convert backlog items to tasks
- `/ccmagic:create-spike` - Create spike from backlog investigation

### With Status Commands
- `/ccmagic:status` - Show backlog metrics
- Include backlog count in status reports
- Track backlog growth rate

### With Context
- Link backlog items to features
- Track which items came from which session
- Associate with user feedback

## Smart Features

### Duplicate Detection
Check for similar items before adding:
```python
def check_duplicates(new_item, backlog):
    for item in backlog:
        similarity = calculate_similarity(new_item.title, item.title)
        if similarity > 0.8:
            return f"Similar item exists: {item.id} - {item.title}"
    return None
```

### Auto-labeling
Apply labels based on content:
- Mentions "API" → add "api" label
- Mentions "UI" or "interface" → add "frontend" label
- Mentions "database" → add "backend" label
- Mentions "slow" or "performance" → add "performance" label

### Backlog Analytics
```markdown
## Backlog Health Metrics

- Total Items: 47
- Average Age: 12 days
- Oldest Item: 45 days (BACKLOG-002)

### By Type
- Features: 20 (43%)
- Bugs: 15 (32%)
- Tech Debt: 8 (17%)
- Enhancements: 4 (8%)

### By Priority
- Critical: 2
- High: 8
- Medium: 22
- Low: 15

### Trends
- Items added this week: 5
- Items completed this week: 3
- Net growth: +2
```

## Output Format

After adding item:

```markdown
✅ Added to backlog

**ID**: BACKLOG-048
**Type**: Feature
**Priority**: High
**Title**: Add user profile management
**Labels**: user-facing, mvp
**Effort**: L

**Current Backlog Stats**:
- Total items: 48
- High priority: 9
- This sprint candidates: 5

Item saved to: .claude/backlog/features/BACKLOG-048.md
```

## Execution

Parse user input immediately to identify backlog item details. Auto-generate ID and timestamp. Detect type, priority, and labels intelligently. Save to appropriate backlog location. Display confirmation with item details and current backlog stats. No confirmation needed before adding.