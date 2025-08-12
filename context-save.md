# Context Save Command

Save the current conversation context, decisions, and project state for future resumption or team handoff.

## What Gets Saved

1. **Conversation History**: Current chat context and decisions made
2. **Project State**: Branch, uncommitted changes, current task
3. **Technical Decisions**: Architecture choices, implementation approach
4. **Todo Items**: Current task list and progress
5. **Code Understanding**: Key files analyzed and their purpose
6. **Environment**: Dependencies, configuration, setup notes

## Implementation

### 1. Gather Context Information

```bash
# Git state
CURRENT_BRANCH=$(git branch --show-current)
COMMIT_HASH=$(git rev-parse HEAD)
UNCOMMITTED=$(git status --porcelain)

# Project info
PROJECT_NAME=$(basename $(pwd))
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")

# Generate unique context ID
CONTEXT_ID="${PROJECT_NAME}-${CURRENT_BRANCH}-${TIMESTAMP}"
```

### 2. Create Context Directory Structure

```bash
# Create context directory
mkdir -p .claude/contexts/$CONTEXT_ID

# Directory structure
.claude/
└── contexts/
    └── $CONTEXT_ID/
        ├── metadata.json
        ├── conversation.md
        ├── project-state.md
        ├── decisions.md
        ├── code-map.md
        ├── todos.md
        └── environment.md
```

### 3. Save Metadata

```json
{
  "id": "project-feature-branch-20240115T143022Z",
  "timestamp": "2024-01-15T14:30:22Z",
  "project": {
    "name": "my-project",
    "path": "/Users/dev/projects/my-project",
    "type": "node-typescript"
  },
  "git": {
    "branch": "feature/user-auth",
    "commit": "abc123def456",
    "ahead": 5,
    "behind": 0,
    "hasUncommitted": true
  },
  "task": {
    "id": "TASK-123",
    "title": "Implement user authentication",
    "progress": 75
  },
  "session": {
    "model": "claude-3-opus",
    "tokenCount": 45000,
    "messageCount": 32
  }
}
```

### 4. Save Conversation Context

```markdown
# Conversation Context
Saved: 2024-01-15T14:30:22Z

## Summary
Working on user authentication feature with JWT tokens and OAuth2 integration.

## Key Decisions Made
1. Using JWT for session management
2. Implementing refresh token rotation
3. OAuth2 providers: Google, GitHub, Microsoft
4. Password hashing with bcrypt (12 rounds)
5. Rate limiting on auth endpoints

## Important Code Locations
- Auth service: `src/services/auth.service.ts`
- JWT utilities: `src/utils/jwt.ts`
- OAuth handlers: `src/auth/oauth/`
- Middleware: `src/middleware/auth.middleware.ts`

## Current Focus
Implementing the password reset flow with email verification.

## Recent Actions
- Created auth service with login/logout
- Added JWT token generation and validation
- Implemented OAuth2 callback handlers
- Added rate limiting middleware
- Created user session management

## Next Steps
1. Complete password reset flow
2. Add email verification
3. Implement MFA support
4. Add audit logging
```

### 5. Save Project State

```markdown
# Project State
Branch: feature/user-auth
Commit: abc123def456

## Changed Files (15)
### Added (8)
- src/services/auth.service.ts
- src/utils/jwt.ts
- src/auth/oauth/google.ts
- src/auth/oauth/github.ts
- src/middleware/auth.middleware.ts
- tests/auth.test.ts
- docs/authentication.md
- .env.example

### Modified (7)
- src/index.ts
- src/routes/api.ts
- package.json
- src/models/user.model.ts
- src/config/auth.config.ts
- README.md
- docker-compose.yml

## Uncommitted Changes
```
M src/services/auth.service.ts
M tests/auth.test.ts
?? src/auth/password-reset.ts
```

## Test Status
- All tests passing ✅
- Coverage: 87.3%
```

### 6. Save Technical Decisions

```markdown
# Technical Decisions

## Architecture Choices

### Authentication Strategy
- **Decision**: JWT with refresh tokens
- **Rationale**: Stateless, scalable, works well with microservices
- **Alternatives Considered**: Sessions, OAuth-only
- **Trade-offs**: Token size vs database lookups

### Password Storage
- **Decision**: bcrypt with 12 rounds
- **Rationale**: Industry standard, good balance of security/performance
- **Alternatives Considered**: Argon2, PBKDF2
- **Trade-offs**: CPU cost vs security level

### OAuth Provider Integration
- **Decision**: Passport.js with custom strategies
- **Rationale**: Well-maintained, extensive provider support
- **Alternatives Considered**: Manual implementation, Auth0
- **Trade-offs**: Dependency vs flexibility

## Implementation Patterns

### Error Handling
- Using custom error classes
- Centralized error middleware
- Consistent error response format

### Validation
- Joi for request validation
- TypeScript for type safety
- Custom validators for business logic

### Testing Strategy
- Unit tests for services
- Integration tests for endpoints
- E2E tests for auth flows
```

### 7. Save Code Map

```markdown
# Code Map

## Core Authentication Files

### Services
- `src/services/auth.service.ts` - Main authentication logic
  - login(), logout(), register(), refreshToken()
  - Password validation and hashing
  - Token generation and validation

### Utilities
- `src/utils/jwt.ts` - JWT token handling
  - generateToken(), verifyToken(), decodeToken()
  - Token refresh logic

### Middleware
- `src/middleware/auth.middleware.ts` - Request authentication
  - requireAuth() - Ensures user is authenticated
  - optionalAuth() - Adds user if authenticated
  - requireRole() - Role-based access control

### OAuth Providers
- `src/auth/oauth/` - OAuth2 implementations
  - google.ts - Google OAuth2 strategy
  - github.ts - GitHub OAuth2 strategy
  - callback.ts - Unified callback handler

### Models
- `src/models/user.model.ts` - User data model
  - User interface and schema
  - Password hashing hooks
  - Token storage

### Routes
- `src/routes/auth.routes.ts` - Authentication endpoints
  - POST /auth/login
  - POST /auth/register
  - POST /auth/logout
  - POST /auth/refresh
  - GET /auth/oauth/:provider
  - GET /auth/oauth/:provider/callback

## Dependencies
- express - Web framework
- jsonwebtoken - JWT handling
- bcrypt - Password hashing
- passport - OAuth strategies
- joi - Validation
```

### 8. Save Todo State

```markdown
# Todo List State

## Completed ✅
- [x] Create auth service structure
- [x] Implement JWT token generation
- [x] Add login endpoint
- [x] Add logout endpoint
- [x] Implement refresh token rotation
- [x] Add OAuth2 Google integration
- [x] Add OAuth2 GitHub integration
- [x] Create auth middleware
- [x] Add rate limiting

## In Progress 🔄
- [ ] Password reset flow (75% complete)
  - [x] Reset request endpoint
  - [x] Token generation
  - [ ] Email sending
  - [ ] Reset confirmation endpoint

## Pending 📋
- [ ] Email verification system
- [ ] Multi-factor authentication (MFA)
- [ ] Audit logging
- [ ] Session management UI
- [ ] Account lockout mechanism
- [ ] Password strength requirements
- [ ] Remember me functionality
- [ ] Social login (Facebook, Twitter)
```

## Context File Format

### Single Archive Option
Create a single context file:

```bash
# Create context archive
tar -czf .claude/contexts/${CONTEXT_ID}.tar.gz \
  metadata.json \
  conversation.md \
  project-state.md \
  decisions.md \
  code-map.md \
  todos.md \
  environment.md

# Or as a single markdown file
cat metadata.json *.md > .claude/contexts/${CONTEXT_ID}.md
```

## Auto-save Triggers

1. **Before Major Operations**
   - Before running `/sync.md`
   - Before creating PR with `/pr.md`
   - Before switching branches

2. **At Milestones**
   - After completing a task
   - After making architectural decisions
   - Before ending a session

3. **Periodic Saves**
   - Every 30 minutes of active work
   - After 50 messages in conversation
   - When context is near token limit

## Integration with Other Commands

- Automatically save before `/handoff.md`
- Include context ID in `/pr.md` description
- Reference in `/status.md` output
- Load with `/context-load.md`

## Sharing Context

### Team Handoff
```bash
# Copy context to shared location
cp -r .claude/contexts/$CONTEXT_ID /shared/contexts/

# Or commit to repository
git add .claude/contexts/$CONTEXT_ID
git commit -m "Save context: $CONTEXT_ID"
```

### Export for Documentation
```bash
# Generate readable report
pandoc .claude/contexts/$CONTEXT_ID/*.md \
  -o context-report.pdf
```

## Execution

Save context immediately without confirmation. Generate unique context ID based on timestamp and branch. Create comprehensive snapshot of current state. Display success message with context ID for future reference. Suggest next actions (continue work, handoff, or close session).