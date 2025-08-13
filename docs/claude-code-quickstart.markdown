# CCMagic Quickstart Guide
## From Theory to Practice: AI-Assisted Development Made Easy

---

## Introduction: What is CCMagic?

CCMagic is a powerful collection of custom slash commands that implement the structured AI-assisted development methodology described in the [Claude Code Team Guide](claude-code-team-guide.markdown). It transforms Claude Code from a coding assistant into a comprehensive project management system that enforces best practices, manages context efficiently, and enables seamless collaboration.

### Why CCMagic?

The Claude Code Team Guide outlines a proven three-phase development process that maximizes AI productivity while avoiding common pitfalls. However, manually following all these practices can be overwhelming. CCMagic automates the process through simple slash commands, making it easy to:

- **Maintain Clean Context**: Automatically organize and load only relevant files
- **Structure Work Hierarchically**: Manage epics → features → tasks effortlessly
- **Create Perfect Handoffs**: Generate comprehensive documentation for team collaboration
- **Track Progress**: Always know what's done, what's in progress, and what's next
- **Optimize AI Usage**: Use the right model for each phase automatically

### How CCMagic Helps Each Role

| Role              | Without CCMagic                                            | With CCMagic                                                                    |
| ----------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Product Owner** | Manually create requirement docs, struggle with formatting | `/ccmagic:plan` creates structured epics automatically                          |
| **Architect**     | Write lengthy architecture docs, hard to maintain          | `/ccmagic:create-features` breaks down epics systematically                     |
| **Tech Lead**     | Spend hours creating task breakdowns                       | `/ccmagic:create-tasks` generates properly-sized tasks                          |
| **Developer**     | Context pollution, lost progress, poor handoffs            | `/ccmagic:start-task` loads clean context, `/ccmagic:checkpoint` saves progress |
| **QA Engineer**   | Unclear test requirements                                  | `/ccmagic:review` and `/ccmagic:validate` ensure quality                        |

---

## Quick Install (2 Minutes)

### For Individual Developers
```bash
# Install globally for all projects
cd ~/.claude/commands/
git clone https://github.com/devondragon/ccmagic.git

# That's it! Commands are now available
```

### For Teams
```bash
# Add to your project (using submodule for updates)
git submodule add https://github.com/devondragon/ccmagic.git .claude/commands/ccmagic
git commit -m "Add CCMagic for team collaboration"

# Team members initialize after cloning
git submodule update --init --recursive
```

---

## Example Project: Pet Profile Web Application

Let's build a complete pet profile application showing how each role uses CCMagic with Claude Code. This example demonstrates the entire workflow from planning to deployment.

### Project Overview
**PetPal**: A web application where pet owners can create profiles for their pets, track health records, share photos, and connect with veterinarians.

### Tech Stack
- Frontend: React + TypeScript
- Backend: Node.js + Express
- Database: PostgreSQL
- Authentication: JWT + OAuth
- Storage: AWS S3 for images

---

## Phase 1: Product Owner & Architect (Strategic Planning)

### Product Owner: Creating the Vision

**Sarah (Product Owner or Architect) starts a Claude Code session:**

```markdown
/ccmagic:init

# CCMagic initializes the project structure
```

```markdown
/ccmagic:plan petpal-app

# Interactive planning session begins
```

**Claude Code (using Opus 4.1 or Zen MCP Planner) prompts:**
```markdown
I'll help you plan the PetPal application. Let me ask some strategic questions:

1. What's the primary business value?
2. Who are the target users?
3. What are the must-have features for MVP?
4. What are the technical constraints?
```

**Sarah provides requirements, and CCMagic generates:**

`context/epics/epic-001-mvp-launch.md`:
```markdown
# Epic 001: MVP Launch

## Business Value
Enable pet owners to digitally manage their pets' lives, creating a
monetizable platform through premium features and vet partnerships.

## Success Criteria
- [ ] Users can create accounts and pet profiles
- [ ] Upload and organize pet photos
- [ ] Track vaccination and health records
- [ ] Find and connect with local vets
- [ ] Share profiles with family members

## Features
1. User Authentication & Onboarding
2. Pet Profile Management
3. Health Record Tracking
4. Photo Gallery
5. Veterinarian Directory

## Target: 4 weeks, 3 developers
```

### Architect: Technical Design

**Tom (Architect) reviews and adds technical architecture:**

```markdown
/ccmagic:create-features epic-001

# CCMagic helps break down the epic
```

**Claude Code generates feature files:**

`context/features/epic-001-f01-authentication/overview.md`:
```markdown
# Feature: User Authentication & Onboarding

## Technical Design
- JWT-based authentication
- OAuth integration (Google, Facebook)
- Email verification flow
- Role-based access (owner, family, vet)

## API Endpoints
- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- GET /auth/verify-email
- POST /auth/oauth/google

## Database Schema
- users table
- sessions table
- oauth_providers table
- email_verifications table

## Tasks (Generated)
1. Database schema setup
2. JWT service implementation
3. Registration endpoint
4. Login endpoint
5. OAuth integration
6. Email verification
7. Frontend auth flow
8. Tests
```

---

## Phase 2: Tech Lead (Feature Design & Task Breakdown)

### Tech Lead: Creating Actionable Tasks

**Mike (Tech Lead) creates detailed tasks:**

```markdown
/ccmagic:create-tasks

# CCMagic prompts for feature selection
```

**CCMagic generates properly-sized tasks:**

`context/features/epic-001-f01-authentication/tasks/todo/001-01-001-database-schema.md`:
```markdown
# Task: Database Schema Setup

## ID: 001-01-001

## Description
Create database schema for user authentication system

## Acceptance Criteria
- [ ] Users table with proper fields
- [ ] Password hashing with bcrypt
- [ ] Email uniqueness constraint
- [ ] Indexes on email and username
- [ ] Sessions table for refresh tokens
- [ ] Audit fields (created_at, updated_at)

## Technical Details
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'owner',
    email_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
```

## Estimated Time: 4 hours

## Dependencies: None

## Files to Create/Modify
- migrations/001_create_users.sql
- src/db/schema/users.ts
- src/db/seed/users.seed.ts
```

---

## Phase 3: Developers (Implementation)

### Developer: Morning Session

**Alex (Developer) starts their day:**

```markdown
/ccmagic:status

# Shows current project state
```

**Output:**
```markdown
## Project Status: PetPal

### Current Sprint
- Epic: 001-MVP Launch
- Active Features: 2
- Total Tasks: 24

### Your Status
- No active task
- Last session: Yesterday 5:30 PM
- Completed this week: 3 tasks

### Team Activity
- Mike: Working on 001-01-002-jwt-service
- Sarah: Reviewing epic-002-premium-features
```

**Alex selects a task:**

```markdown
/ccmagic:start-task 001-01-001

# CCMagic loads ONLY relevant context
```

**Claude Code response:**
```markdown
## Task Started: Database Schema Setup

I've loaded:
- Task requirements
- Project database conventions
- Existing migration patterns

Let's implement the user authentication schema:

1. First, I'll create the migration file
2. Then the TypeScript schema
3. Finally, seed data for testing

Shall we begin?
```

**Alex works with Claude:**
```markdown
Yes, let's create the migration. Follow our pattern in migrations/
```

**Claude Code implements:**
```typescript
// Created: migrations/001_create_users.sql
-- User authentication schema
BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'owner' CHECK (role IN ('owner', 'family', 'vet', 'admin')),
    email_verified BOOLEAN DEFAULT false,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);

-- Sessions for JWT refresh tokens
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token VARCHAR(255) UNIQUE NOT NULL,
    token_family UUID NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(refresh_token);

COMMIT;
```

### Developer: Mid-Morning Checkpoint

**After 2 hours of work:**

```markdown
/ccmagic:checkpoint

# Saves progress automatically
```

**CCMagic creates** `context/sessions/2025-01-13-checkpoint.md`:
```markdown
# Checkpoint: 2025-01-13 10:30 AM

## Task: 001-01-001-database-schema

### Completed (75%)
✅ Created migration file
✅ Added TypeScript types
✅ Implemented seed data
✅ Added indexes

### Remaining (25%)
❌ Run migration in dev
❌ Test rollback
❌ Update documentation

### Decisions Made
- Using UUID v4 for IDs (better for distributed systems)
- Added token_family for refresh token rotation
- Separate sessions table for scalability

### Next Steps
1. Run: npm run db:migrate
2. Test with: npm run db:seed
3. Verify indexes with EXPLAIN ANALYZE
```

### Developer: Handling Context Limits

**When context gets full:**

```markdown
# Claude Code becomes slower, Alex notices

/ccmagic:handoff

# Creates comprehensive handoff
```

**CCMagic generates handoff:**
```markdown
# Handoff Created: 001-01-001-database-schema

## Status: 75% Complete

### What's Done
- ✅ All schema files created
- ✅ Migration tested locally
- ✅ TypeScript types match schema

### How to Continue
1. Start fresh Claude Code session
2. Run: /ccmagic:start-task 001-01-001
3. The remaining work is in the task file
4. Focus on testing the rollback procedure

### Key Context
- We chose UUID over serial IDs
- Token rotation is critical for security
- Check with Mike about session expiry policy

### Files Modified
- migrations/001_create_users.sql (new)
- src/db/schema/users.ts (new)
- src/db/schema/sessions.ts (new)
- src/db/seed/users.seed.ts (new)
```

**Alex starts fresh session:**
```markdown
/ccmagic:context-load

# Loads handoff and continues efficiently
```

### Developer: Completing the Task

**After finishing implementation:**

```markdown
/ccmagic:validate

# Runs validation checks
```

**Output:**
```markdown
## Validation Results

✅ TypeScript compilation successful
✅ ESLint: No errors
✅ Tests: 8/8 passing
✅ Migration runs successfully
✅ Rollback tested

⚠️ Warning: Consider adding email validation regex
💡 Suggestion: Add composite index on (email, email_verified)

Ready to complete task!
```

```markdown
/ccmagic:complete-task 001-01-001

# Moves task to completed
```

---

## Phase 4: QA & Code Review

### QA Engineer: Testing the Implementation

**Lisa (QA Engineer) reviews completed tasks:**

```markdown
/ccmagic:review --scope=epic-001-f01

# Reviews all authentication feature code
```

**Claude Code (using specialized model) performs review:**
```markdown
## Code Review: Authentication Feature

### Security Analysis
✅ Passwords properly hashed with bcrypt
✅ SQL injection prevented (parameterized queries)
⚠️ Missing rate limiting on login endpoint
❌ No account lockout after failed attempts

### Performance
✅ Proper indexes on frequently queried fields
✅ Connection pooling configured
💡 Consider caching session lookups in Redis

### Code Quality
✅ Consistent error handling
✅ TypeScript types match database schema
✅ Good test coverage (85%)

### Recommendations
1. Add rate limiting middleware
2. Implement account lockout mechanism
3. Add Redis for session caching
4. Increase test coverage to 90%
```

---

## Real-World Workflow Examples

### Example 1: Spike for Technical Research

**When facing unknowns:**

```markdown
/ccmagic:create-spike

Title: Research image storage solutions
Description: Evaluate S3 vs Cloudinary for pet photos
Time-box: 8 hours
```

**CCMagic creates** `context/spikes/todo/spike-001-image-storage.md`

**Developer starts research:**
```markdown
/ccmagic:start-spike spike-001

# Loads research task
```

### Example 2: Handling Blocked Tasks

**When blocked on dependencies:**

```markdown
/ccmagic:status

Current task 001-02-003 is blocked on database setup.
Let me check for unblocked tasks...

/ccmagic:start-task --next-available

# Automatically finds unblocked work
```

### Example 3: Team Sync

**Daily standup preparation:**

```markdown
/ccmagic:status --team

## Team Status

### Mike (Tech Lead)
- Yesterday: Completed 001-01-002-jwt-service
- Today: Starting 001-01-003-registration
- Blocked: None

### Alex (Developer)
- Yesterday: 001-01-001-database-schema (75%)
- Today: Completing database, starting 001-01-004
- Blocked: Need OAuth client IDs

### Lisa (QA)
- Yesterday: Test plan for authentication
- Today: Testing completed tasks
- Blocked: Waiting for 001-01-003
```

### Example 4: End of Sprint

**Preparing for sprint review:**

```markdown
/ccmagic:status --sprint-summary

## Sprint Summary: Week 1

### Completed
- Epic 001, Feature 01: 6/8 tasks (75%)
- Epic 001, Feature 02: 2/5 tasks (40%)

### In Progress
- 001-01-003: Registration endpoint (Mike)
- 001-02-003: Pet schema (Alex)

### Blocked
- 001-01-005: OAuth (waiting for client IDs)

### Velocity
- Planned: 13 tasks
- Completed: 8 tasks
- Carry-over: 5 tasks

### Recommendations
- Reduce task size (several took >8 hours)
- Add buffer for testing
- Earlier spike for OAuth research
```

---

## Advanced CCMagic Features

### Custom Model Selection

**For complex architectural decisions:**
```markdown
/ccmagic:plan --model=opus-4

# Uses most advanced model for deep thinking
```

**For simple tasks:**
```markdown
/ccmagic:start-task 001-01-008-readme --model=haiku

# Uses fast, cheap model for simple work
```

### Parallel Development

**Working on multiple features:**
```markdown
/ccmagic:status --my-tasks

You have 3 assigned tasks across 2 features.
Recommended order based on dependencies:
1. 001-01-004 (no dependencies)
2. 001-02-001 (no dependencies)
3. 001-01-007 (depends on 001-01-004)
```

### Context Optimization

**Before starting complex debugging:**
```markdown
/ccmagic:context-save --minimal

# Saves current state with minimal context
```

**Then:**
```markdown
/ccmagic:debug 001-01-003

# Loads only debugging-relevant context
```

---

## Troubleshooting Common Issues

### Issue: "Context limit reached"

```markdown
/ccmagic:checkpoint --emergency

# Saves everything immediately
```

Then start fresh:
```markdown
/ccmagic:context-load --continue

# Loads minimal context to continue
```

### Issue: "Lost track of current work"

```markdown
/ccmagic:status --detailed

# Shows everything about current state
```

### Issue: "Need to switch tasks urgently"

```markdown
/ccmagic:checkpoint --switch-to 001-02-005

# Saves current, switches to new task
```

### Issue: "Unclear task requirements"

```markdown
/ccmagic:task-details 001-01-003 --explain

# Claude explains task in detail
```

---

## Best Practices with CCMagic

### DO's ✅

1. **Start every work or task session with** `/clear`
2. **Checkpoint every 1-2 hours** with `/ccmagic:checkpoint`
3. **Complete one task** before starting another
4. **Use spikes** for research and unknowns
5. **Create handoffs** when switching contexts
6. **Update task status** immediately when done
7. **Run validation** before marking complete

### DON'Ts ❌

1. **Don't load entire codebase** - Let CCMagic manage context
2. **Don't skip checkpoints** - You'll regret it
3. **Don't mix tasks** in one session
4. **Don't ignore handoffs** from teammates
5. **Don't modify task files** directly - Use commands
6. **Don't work without a task** - Create one first

---

## Integration with CI/CD

### GitHub Actions Integration

**.github/workflows/ccmagic.yml:**
```yaml
name: CCMagic Validation

on:
  pull_request:
    paths:
      - 'context/features/**/tasks/completed/*.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Validate completed tasks
        run: |
          claude code "/ccmagic:validate --ci"

      - name: Check task completion
        run: |
          claude code "/ccmagic:status --verify-pr"
```

### Pre-commit Hooks

**.git/hooks/pre-commit:**
```bash
#!/bin/bash
# Ensure task is marked complete before committing

if git diff --cached --name-only | grep -q "src/"; then
  claude code "/ccmagic:validate --pre-commit"
fi
```

---

## Metrics & Reporting

### Individual Developer Metrics

```markdown
/ccmagic:metrics --personal --week

⏺ 📊 Personal Weekly Metrics

  Period: Aug 6-13, 2025

  🎯 Productivity Summary

  Work Output

  - Commits: 6 total
  - Tasks Completed: 2 (001-01-001, 001-01-002)
  - Lines Written: +122,629 (includes dependencies)
  - Files Modified: 1,093

  Commit Pattern

  Aug 12: ██████ (6 commits)
  Peak Day: Monday (project kickoff)

  📈 Code Contributions

  Commit Types

  - 🚀 Features: 2 (50%)
  - 🔧 Chores: 2 (50%)
  - 🐛 Fixes: 0
  - 📚 Docs: 0

  Key Achievements

  1. ✅ Initialized Node.js project structure
  2. ✅ Set up Express server with middleware
  3. ✅ Configured health endpoints
  4. ✅ Established CCMagic workflow

  ⏱️ Time Analysis

  Activity Timeline

  - First Commit: 06:40 (Project init)
  - Last Commit: 07:26 (Feature merge)
  - Active Duration: ~47 minutes of commits
  - Focus: Single-day sprint execution

  📊 Progress Metrics

  Feature Completion

  001-01-setup: 29% complete (2/7 tasks)
  - Environment setup: ✅
  - Express configuration: ✅
  - Remaining: 5 infrastructure tasks

  Velocity

  - Daily Average: 2 tasks/active day
  - Commit Frequency: 6 commits/active day
  - Feature Progress: On track

  🎖️ Strengths This Week

  - ✨ Clean commit messages with conventional format
  - 🎯 Focused single-feature development
  - 📁 Well-organized context structure
  - 🔄 Proper branch management

  🚀 Momentum Score: 7/10

  Strong project kickoff with solid foundation laid. Ready to continue setup tasks.

  📅 Next Week Goals

  1. Complete environment configuration (001-01-003)
  2. Set up testing framework
  3. Configure Docker
  4. Aim for 3-4 tasks completion
```

---

## Quick Reference Card

### Essential Commands

| When You Want To... | Use This Command                              |
| ------------------- | --------------------------------------------- |
| Start your day      | `/ccmagic:status`                             |
| Begin new work      | `/ccmagic:start-task`                         |
| Save progress       | `/ccmagic:checkpoint`                         |
| Switch tasks        | `/ccmagic:handoff` then `/ccmagic:start-task` |
| End your day        | `/ccmagic:checkpoint --end-of-day`            |
| Review code         | `/ccmagic:review`                             |
| Create PR           | `/ccmagic:pr`                                 |
| Get help            | `/ccmagic:help`                               |

### Task State Transitions

```
TODO → CURRENT → COMPLETED
        ↓
    BLOCKED → TODO
```

### Context Management

```
Fresh Start (0-25%) → Productive (25-50%) → Checkpoint (50-70%) → Handoff (70-90%) → Emergency Save (90-100%)
```

---

## Getting Started Checklist

### Day 1: Setup (30 minutes)
- [ ] Install CCMagic
- [ ] Run `/ccmagic:init` in your project
- [ ] Read generated `CLAUDE.md`
- [ ] Try `/ccmagic:status`

### Day 2: First Task (2 hours)
- [ ] Run `/ccmagic:plan` for simple project
- [ ] Create one epic with `/ccmagic:create-features`
- [ ] Generate tasks with `/ccmagic:create-tasks`
- [ ] Complete one task using commands

### Week 1: Build Habits
- [ ] Start every session with `/ccmagic:status`
- [ ] Checkpoint every 2 hours
- [ ] Create one handoff
- [ ] Review your metrics

### Week 2: Team Collaboration
- [ ] Share CCMagic with team
- [ ] Practice handoffs between developers
- [ ] Use `/ccmagic:review` for code review
- [ ] Run team metrics

---

## Conclusion

CCMagic transforms the theory from the Claude Code Team Guide into practice through simple, powerful commands. It enforces best practices automatically, manages context efficiently, and enables teams to scale their AI-assisted development.

Whether you're a solo developer building an MVP or a team delivering enterprise software, CCMagic provides the structure and automation needed to maximize productivity with Claude Code.

### Next Steps

1. **Install CCMagic** in your project
2. **Run** `/ccmagic:init` to set up structure
3. **Start with** `/ccmagic:plan` for your next feature
4. **Build the habit** of checkpoints and handoffs
5. **Share** with your team for multiplied productivity

Remember: CCMagic isn't just about commands—it's about establishing a sustainable, scalable development process that grows with your project and team.

---

*Start using CCMagic today and experience the difference structured AI-assisted development makes!*
