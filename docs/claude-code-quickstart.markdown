# Claude Code Quick Start Guide & Examples
## Get Your Team Productive in 30 Minutes

---

## Day 1: Developer Quick Start

### Step 1: Setup Your Workspace (5 minutes)

```bash
# Run this setup script in your project root
#!/bin/bash

# Create Claude Code directory structure
mkdir -p .claude/context
mkdir -p .claude/sessions
mkdir -p planning/requirements
mkdir -p planning/epics
mkdir -p planning/tasks

# Create initial context files
cat > .claude/context/project-overview.md << 'EOF'
# Project Overview
## Tech Stack
- Frontend: [Your framework]
- Backend: [Your framework]
- Database: [Your database]

## Key Conventions
- API Format: REST/GraphQL
- Auth: JWT/Sessions
- Testing: Jest/Mocha

## Important Patterns
- Error handling: See src/utils/errors
- API responses: See src/types/api
EOF

cat > .claude/context/aliases.md << 'EOF'
# Quick References
- TASK_DIR: planning/tasks/
- CURRENT_EPIC: [Update this]
- DB_SCHEMA: src/database/schema
- API_ROUTES: src/routes
EOF

echo "✅ Claude Code workspace ready!"
```

### Step 2: Your First Claude Code Session (10 minutes)

#### Launch Claude Code
```bash
# In your project directory
claude code
```

#### Initial Context Load
```markdown
Hi! I'm starting a new development session. Please:
1. Read .claude/context/project-overview.md to understand our project
2. Confirm you understand our tech stack and conventions
3. Ask me which task I'm working on today
```

#### Load Your Task
```markdown
I'm working on TASK-001. Please read planning/tasks/EPIC-001/TASK-001-database-schema.md and let's implement it together.
```

### Step 3: Develop with Claude Code (15 minutes)

#### Example: Implementing a Database Schema Task

**Your prompt:**
```markdown
Let's implement the user database schema task. Please:
1. Create the TypeORM entity
2. Generate the migration
3. Add appropriate indexes
4. Include audit fields

Follow our existing patterns in src/entities/
```

**Claude Code will:**
1. Create the entity file
2. Generate migration
3. Show you the code
4. Run tests if requested

#### Save Progress Before Break
```markdown
Please document what we've completed so far in .claude/sessions/current.md including:
- Files created
- Decisions made
- What's left to do
```

---

## Real-World Example: Building an Authentication Feature

### Phase 1: Architect Creates Epic (Using Opus)

**Input Prompt to Opus:**
```markdown
Create a feature epic for user authentication with these requirements:
- Email/password login
- OAuth2 (Google, GitHub)
- JWT tokens with refresh
- Rate limiting
- Account lockout after failed attempts

Our tech stack:
- Node.js + Express
- PostgreSQL
- Redis for sessions
- React frontend
```

**Output: EPIC-001-user-authentication.md**
```markdown
# EPIC-001: User Authentication System

## Business Value
Secure user authentication is fundamental to protecting user data and enabling personalized experiences. This implementation will reduce support burden through self-service password reset and improve user experience with social login options.

## Success Criteria
- [ ] Users can register with email/password
- [ ] Users can login with email/password
- [ ] OAuth2 integration with Google and GitHub
- [ ] JWT tokens with 15-minute access, 7-day refresh
- [ ] Rate limiting: 5 attempts per minute per IP
- [ ] Account lockout after 5 failed attempts
- [ ] Password reset via email
- [ ] Session management with Redis
- [ ] Audit logging for all auth events

## Technical Architecture
```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ React   │────▶│ Express │────▶│PostgreSQL│
│ Frontend│     │   API   │     │ Database │
└─────────┘     └─────────┘     └─────────┘
                     │
                     ▼
                ┌─────────┐
                │  Redis  │
                │ Sessions│
                └─────────┘
```

## Dependencies
- Email service configured (SendGrid/AWS SES)
- OAuth apps created (Google, GitHub)
- Redis instance available
- SSL certificates for production

## Risk Assessment
- **High**: OAuth provider downtime → Implement fallback to email/password
- **Medium**: Redis failure → Implement graceful degradation
- **Low**: Rate limit too restrictive → Monitor and adjust

## Estimated Effort
- 3 developers × 1 week = 15 person-days
- ~20 individual tasks
```

### Phase 2: Tech Lead Creates Tasks (Using Opus)

**Input Prompt to Opus:**
```markdown
Break down this authentication epic into specific tasks:
[Paste EPIC-001 content]

Each task should:
- Be completable in 4-8 hours
- Have clear acceptance criteria
- Include technical details
- Specify dependencies
```

**Output Example: TASK-003-jwt-implementation.md**
```markdown
# TASK-003: Implement JWT Token Management

## Parent Epic
EPIC-001: User Authentication

## Description
Implement JWT token generation, validation, and refresh logic with proper security measures.

## Acceptance Criteria
- [ ] Generate access tokens (15-minute expiry)
- [ ] Generate refresh tokens (7-day expiry)
- [ ] Validate tokens on protected routes
- [ ] Implement token refresh endpoint
- [ ] Blacklist revoked tokens in Redis
- [ ] Include user roles in token claims
- [ ] Implement token rotation on refresh

## Technical Implementation

### Token Structure
```javascript
// Access Token Payload
{
  sub: userId,
  email: userEmail,
  roles: ['user', 'admin'],
  type: 'access',
  iat: timestamp,
  exp: timestamp + 900 // 15 minutes
}

// Refresh Token Payload
{
  sub: userId,
  tokenFamily: uuid, // For rotation tracking
  type: 'refresh',
  iat: timestamp,
  exp: timestamp + 604800 // 7 days
}
```

### Required Files
- `src/auth/jwt.service.ts` - Token generation/validation
- `src/auth/jwt.middleware.ts` - Route protection
- `src/auth/refresh.controller.ts` - Refresh endpoint
- `src/auth/jwt.types.ts` - TypeScript interfaces

### Environment Variables
```env
JWT_ACCESS_SECRET=<generate-strong-secret>
JWT_REFRESH_SECRET=<different-strong-secret>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d
```

## Dependencies
- TASK-001: Database schema (users table must exist)
- TASK-002: Redis setup (for blacklist)

## Testing Requirements
- Unit tests for token generation/validation
- Integration tests for refresh flow
- Test token expiration
- Test invalid token handling

## Estimated Time
6 hours

## Context for Claude Code
- Use `jsonwebtoken` library
- Follow existing service pattern in `src/services/`
- See `src/auth/auth.types.ts` for interfaces
- Redis client available at `src/cache/redis.client.ts`
```

### Phase 3: Developer Implementation (Using Claude Code + Sonnet)

**Session 1: Starting the Task**

```markdown
# In Claude Code

I'm starting TASK-003-jwt-implementation. Please:
1. Read planning/tasks/EPIC-001/TASK-003-jwt-implementation.md
2. Check if src/auth/ directory exists, if not create it
3. Let's implement the JWT service first
```

**Claude Code's Response & Actions:**
```typescript
// Created: src/auth/jwt.types.ts
export interface AccessTokenPayload {
  sub: string;
  email: string;
  roles: string[];
  type: 'access';
}

export interface RefreshTokenPayload {
  sub: string;
  tokenFamily: string;
  type: 'refresh';
}

// Created: src/auth/jwt.service.ts
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { redisClient } from '../cache/redis.client';
import { AccessTokenPayload, RefreshTokenPayload } from './jwt.types';

export class JWTService {
  private readonly accessSecret = process.env.JWT_ACCESS_SECRET!;
  private readonly refreshSecret = process.env.JWT_REFRESH_SECRET!;

  generateTokenPair(userId: string, email: string, roles: string[]) {
    const tokenFamily = uuidv4();

    const accessToken = jwt.sign(
      {
        sub: userId,
        email,
        roles,
        type: 'access'
      } as AccessTokenPayload,
      this.accessSecret,
      { expiresIn: '15m' }
    );

    const refreshToken = jwt.sign(
      {
        sub: userId,
        tokenFamily,
        type: 'refresh'
      } as RefreshTokenPayload,
      this.refreshSecret,
      { expiresIn: '7d' }
    );

    return { accessToken, refreshToken, tokenFamily };
  }

  // ... more implementation
}
```

**Mid-Session Progress Check:**
```markdown
We've been working for a while. Please:
1. Summarize our progress on TASK-003
2. Check which acceptance criteria are complete
3. Save progress to .claude/sessions/current.md
```

**Session 2: Continuing After Break**

```markdown
I'm resuming work on TASK-003. Please:
1. Read .claude/sessions/current.md to see our progress
2. Show me what acceptance criteria remain
3. Let's continue with the token refresh logic
```

---

## Common Scenarios & Solutions

### Scenario 1: Context Limit Approaching

**Warning Signs:**
- Claude Code becomes slower
- Responses get shorter
- "I need to be concise" messages

**Solution:**
```markdown
We're hitting context limits. Please:
1. Create a comprehensive handoff in .claude/sessions/handoff-$(date).md
2. List exactly what's complete and what remains
3. Include any setup commands needed to continue

Then I'll start a fresh session.
```

### Scenario 2: Complex Debugging

**Using Zen Tools:**
```markdown
The authentication is failing with a 401 error. Please use zen:debug to:
1. Trace through the JWT validation flow
2. Check Redis for the token
3. Verify the token signature
4. Find the root cause
```

### Scenario 3: Need Documentation

**Using Context7:**
```markdown
I need to implement Stripe webhooks. Please:
1. Use Context7 to get the latest Stripe webhook documentation
2. Find the recommended Node.js implementation
3. Implement following their best practices
```

### Scenario 4: Code Review Before PR

```markdown
The feature is complete. Please use zen:codereview to:
1. Check for security vulnerabilities
2. Verify error handling
3. Assess code quality
4. Suggest improvements
Focus on the files in src/auth/
```

---

## Team Coordination Examples

### Daily Standup Format

```markdown
## Date: 2025-01-05
## Developer: John

### Yesterday
- Completed: TASK-003-jwt-implementation
- Session notes: .claude/sessions/20250104-142000.md

### Today
- Starting: TASK-004-oauth-google
- Blocked: None

### Claude Code Sessions
- Morning: 2 hours on TASK-004
- Afternoon: Testing and documentation

### Token Usage
- Used: ~60% of daily quota
- Remaining: Sufficient for today's tasks
```

### Handoff Between Developers

**Developer A's Handoff:**
```markdown
# Handoff: TASK-005-password-reset
## Date: 2025-01-05 15:30

### Completed (70%)
✅ Email template created
✅ Reset token generation
✅ Database schema updated
✅ Email sending service

### Remaining (30%)
❌ Reset endpoint implementation
❌ Token validation
❌ Password update logic
❌ Tests

### Key Decisions
- Using 6-digit code instead of link (mobile-friendly)
- 1-hour expiration for security
- Rate limited to 3 requests per hour

### To Continue
1. Run: npm install (I added nodemailer)
2. Check .env.example for new variables
3. Start with src/auth/reset.controller.ts
4. Pattern follows src/auth/login.controller.ts

### Watch Out
- Email service requires API key (ask team lead)
- Database migration needs to run first
- Redis must be running for rate limiting
```

---

## Troubleshooting Guide

### Issue: "Claude doesn't understand my project"

**Fix:**
```markdown
Please read and confirm understanding of:
1. .claude/context/project-overview.md - Our architecture
2. .claude/context/database-standards.md - Our DB conventions
3. .claude/context/api-patterns.md - Our API patterns

Now, let me restate my question: [your question]
```

### Issue: "Claude keeps suggesting wrong patterns"

**Fix:**
```markdown
IMPORTANT: We have specific patterns to follow.
Instead of your suggestion, please:
1. Check how we handle this in src/[similar-feature]/
2. Follow that exact pattern
3. Ask if you're unsure about our conventions
```

### Issue: "Running out of tokens too quickly"

**Fix:**
1. Batch similar tasks together
2. Use references instead of pasting code
3. Clear context between unrelated work
4. Use shorthand references:
```markdown
# Instead of pasting whole file:
"Update the user service (you can see it at src/services/user.service.ts)"

# Instead of explaining everything:
"Implement TASK-006 from planning/tasks/EPIC-001/"
```

### Issue: "Handoffs aren't working well"

**Fix - Better Handoff Template:**
```markdown
Create handoff with these EXACT sections:
1. One-line status: "TASK-X: 60% complete"
2. Bullet list of completed files (with paths)
3. Bullet list of remaining work
4. Code snippet showing where to continue
5. Exact command to run before starting
6. One critical warning or gotcha
```

---

## Measuring Success

### Individual Metrics
- Tasks completed per week
- Average session length
- Token efficiency (tasks per quota)
- Handoff success rate

### Team Metrics
- Epic completion time
- Code review iterations
- Production bugs per epic
- Developer satisfaction

### Weekly Retrospective Questions
1. Which Claude Code patterns worked well?
2. Where did we hit token limits?
3. Which handoffs failed and why?
4. How can we improve task definitions?

---

## Next Steps

1. **Week 1**: Everyone completes one simple task with Claude Code
2. **Week 2**: Try pair programming with Claude Code
3. **Week 3**: Implement a full epic with the process
4. **Week 4**: Retrospective and process refinement

Remember: The goal is to augment your development, not replace your thinking. Claude Code is most effective when you provide clear context and maintain good documentation habits.
