# Claude Code Team Implementation Guide
## Optimized for Claude Pro (Sonnet) Users

---

## Table of Contents
1. [Overview & Architecture](#overview--architecture)
2. [Understanding Context & Token Management](#understanding-context--token-management)
3. [Phase 1: Strategic Planning](#phase-1-strategic-planning)
4. [Phase 2: Tactical Breakdown](#phase-2-tactical-breakdown)
5. [Phase 3: Development Execution](#phase-3-development-execution)
6. [File Structure & Naming Conventions](#file-structure--naming-conventions)
7. [Template Prompts](#template-prompts)
8. [Best Practices & Tips](#best-practices--tips)

---

## Overview & Architecture

### Three-Phase Development Workflow

```mermaid
graph TD
    A[Business Requirements] -->|Opus/Gemini 2.5 Pro| B[Feature Epics]
    B -->|Opus| C[Detailed Tasks]
    C -->|Sonnet + Claude Code| D[Implementation]
    D --> E[Code Review & Testing]
```

### Role Distribution
- **Architects**: Strategic planning with Opus/Gemini 2.5 Pro
- **Tech Leads**: Task breakdown with Opus
- **Developers**: Implementation with Claude Code + Sonnet

---

## Understanding Context & Token Management

### What is Context?
Context is everything Claude "remembers" during a conversation:
- Your code files
- Previous messages in the conversation
- Documentation you've shared
- The current state of your project

### Token Limits for Claude Pro Users
- **Sonnet 3.5**: ~200K context window
- **Daily limits**: Varies, but typically 5-10 longer sessions
- **Strategy**: Maximize value per session by batching related tasks

### Context Management Best Practices

1. **Clear context between unrelated tasks**
   - Start new conversations for different features
   - Use the `/reset` command in Claude Code when switching contexts

2. **Preserve context within related work**
   - Keep working in the same session for related tasks
   - Save progress summaries before context limits

3. **Use reference documents**
   - Instead of re-explaining, point to markdown files
   - Example: "See `/context/project-overview.md` for architecture"

---

## Phase 1: Strategic Planning
*Led by Architects using Opus or Gemini 2.5 Pro*

### Objective
Transform business requirements into well-defined feature epics.

### Process
1. **Input**: Business requirements document
2. **Output**: Feature epic documents
3. **Tool**: Claude Web UI with Opus or Gemini 2.5 Pro

### Deliverable Structure
```
/planning/
├── requirements/
│   └── business-requirements.md
└── epics/
    ├── EPIC-001-user-authentication.md
    ├── EPIC-002-payment-processing.md
    └── EPIC-003-reporting-dashboard.md
```

### Epic Document Template
```markdown
# EPIC-001: User Authentication

## Business Value
[Why this feature matters]

## Success Criteria
- [ ] Users can register with email
- [ ] Multi-factor authentication available
- [ ] Session management implemented

## Technical Considerations
- JWT token architecture
- PostgreSQL user storage
- Redis session cache

## Dependencies
- Database schema must be finalized
- Email service provider selected

## Estimated Scope
- 3-4 developer weeks
- 15-20 individual tasks
```

---

## Phase 2: Tactical Breakdown
*Led by Tech Leads using Opus*

### Objective
Decompose epics into actionable, well-defined tasks.

### Process
1. **Input**: Epic documents
2. **Output**: Detailed task lists with acceptance criteria
3. **Tool**: Claude Web UI with Opus

### Task Document Structure
```
/planning/
└── tasks/
    ├── EPIC-001/
    │   ├── TASK-001-database-schema.md
    │   ├── TASK-002-registration-api.md
    │   ├── TASK-003-login-endpoint.md
    │   └── TASK-004-jwt-implementation.md
    └── EPIC-002/
        └── ...
```

### Task Document Template
```markdown
# TASK-001: Create User Database Schema

## Parent Epic
EPIC-001: User Authentication

## Description
Design and implement PostgreSQL schema for user management.

## Acceptance Criteria
- [ ] Users table with required fields
- [ ] Indexes for email and username
- [ ] Audit fields (created_at, updated_at)
- [ ] Migration scripts ready

## Technical Details
```sql
-- Expected schema
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Dependencies
- PostgreSQL 14+ installed
- Database connection configured

## Estimated Time
2-3 hours

## Context for Claude Code
- Use TypeORM for migrations
- Follow existing database naming conventions
- See `/context/database-standards.md`
```

---

## Phase 3: Development Execution
*Developers using Claude Code with Sonnet*

### Pre-Session Setup

1. **Prepare your workspace**
```bash
# Create context directory
mkdir -p .claude/context
mkdir -p .claude/sessions

# Copy relevant task file
cp planning/tasks/EPIC-001/TASK-001-database-schema.md .claude/context/current-task.md
```

2. **Create session journal**
```bash
# Create a new session file with timestamp
echo "# Session: $(date +%Y%m%d-%H%M%S)" > .claude/sessions/current.md
echo "## Task: TASK-001-database-schema" >> .claude/sessions/current.md
```

### Claude Code Session Management

#### Starting a New Task
```bash
# Clear previous context
/reset

# Load task context
"Please read the task definition in .claude/context/current-task.md and confirm understanding"

# Load project context if needed
"Also review .claude/context/project-overview.md for architecture patterns"
```

#### During Development
```bash
# Regular progress saves
"Please summarize what we've completed so far and save to .claude/sessions/current.md"

# Before context limit
"We're approaching context limits. Please create a handoff document with:
1. What's completed
2. What's remaining
3. Key decisions made
4. Next steps"
```

#### Task Completion
```bash
# Final documentation
"Please update .claude/sessions/current.md with:
- All files created/modified
- Key implementation decisions
- Testing notes
- Any remaining TODOs"
```

### Working with MCP Servers

#### Context7 for Documentation
```bash
# When you need framework documentation
"Use Context7 to look up Next.js routing documentation"

# For API references
"Check Context7 for Stripe payment integration docs"
```

#### Zen Tools for Complex Problems
```bash
# For debugging
"Use zen:debug to investigate why the authentication is failing"

# For code review
"Use zen:codereview to analyze the security of our JWT implementation"

# For refactoring
"Use zen:refactor to improve the database query performance"
```

---

## File Structure & Naming Conventions

### Complete Project Structure
```
project-root/
├── .claude/                      # Claude Code specific files
│   ├── context/                  # Persistent context documents
│   │   ├── project-overview.md
│   │   ├── architecture.md
│   │   ├── database-standards.md
│   │   ├── api-patterns.md
│   │   └── current-task.md       # Symlink or copy of active task
│   └── sessions/                 # Session journals
│       ├── 20250105-091500.md
│       └── current.md            # Active session
├── planning/                     # Planning documents
│   ├── requirements/
│   │   └── business-requirements.md
│   ├── epics/
│   │   ├── EPIC-001-user-authentication.md
│   │   └── EPIC-002-payment-processing.md
│   └── tasks/
│       ├── EPIC-001/
│       │   ├── TASK-001-database-schema.md
│       │   └── TASK-002-registration-api.md
│       └── EPIC-002/
│           └── TASK-010-stripe-integration.md
└── src/                          # Your actual source code
    └── ...
```

### Naming Conventions

#### Epics
- Format: `EPIC-{number}-{kebab-case-name}.md`
- Example: `EPIC-001-user-authentication.md`

#### Tasks
- Format: `TASK-{number}-{kebab-case-name}.md`
- Example: `TASK-001-database-schema.md`
- Numbering: Sequential within epic

#### Sessions
- Format: `{YYYYMMDD}-{HHMMSS}.md`
- Example: `20250105-143000.md`

---

## Template Prompts

### For Architects (Strategic Planning)

#### Initial Epic Creation
```markdown
I need to create feature epics from these business requirements:

[Paste requirements]

Please create detailed epic documents that include:
1. Clear business value proposition
2. Measurable success criteria
3. Technical considerations and constraints
4. Dependencies on other epics or external factors
5. Rough scope estimation

Format as separate markdown documents following the EPIC-XXX naming convention.
```

#### Epic Refinement
```markdown
Review this epic and identify:
1. Any ambiguous requirements that need clarification
2. Technical risks or challenges
3. Potential scope creep areas
4. Missing success criteria

Epic: [Paste epic content]
```

### For Tech Leads (Task Breakdown)

#### Task Generation from Epic
```markdown
Break down this epic into detailed development tasks:

[Paste epic content]

For each task, provide:
1. Clear, actionable description
2. Specific acceptance criteria
3. Technical implementation details
4. Dependencies
5. Time estimation (in hours)
6. Context notes for developers using Claude Code

Each task should be completable in 4-8 hours of focused work.
```

#### Task Validation
```markdown
Review these tasks and verify:
1. No task exceeds 8 hours of work
2. Dependencies are clearly stated
3. Acceptance criteria are testable
4. Technical details are sufficient for implementation

Tasks: [Paste task list]
```

### For Developers (Implementation)

#### Session Start
```markdown
I'm starting work on a new task. Please:
1. Read the task definition in .claude/context/current-task.md
2. Review the project overview in .claude/context/project-overview.md
3. Confirm your understanding of the requirements
4. Suggest an implementation approach
```

#### Context Refresh (Mid-Session)
```markdown
We've been working on [task description]. Please:
1. Summarize what we've completed so far
2. List remaining acceptance criteria
3. Identify any blockers or issues
4. Suggest next steps
```

#### Progress Documentation
```markdown
Please document our progress in .claude/sessions/current.md:

## Completed
- [List what's done]

## In Progress
- [Current work]

## Remaining
- [What's left]

## Key Decisions
- [Important choices made]

## Files Modified
- [List of files changed]
```

#### Handoff Creation (Before Context Limit)
```markdown
We're approaching context limits. Create a handoff document that includes:

1. Current state of the task (% complete)
2. All files created or modified with brief descriptions
3. Key implementation decisions and why they were made
4. Exact next steps to continue
5. Any gotchas or warnings for the next session
6. Commands or setup needed to resume

Save this as .claude/sessions/handoff-[timestamp].md
```

#### Task Completion
```markdown
The task is complete. Please:
1. Verify all acceptance criteria are met
2. Document the final implementation in .claude/sessions/current.md
3. List any follow-up tasks or improvements identified
4. Create a brief summary for the task tracking system
```

### For Complex Problem Solving

#### Using Zen Debug
```markdown
I'm encountering an issue with [describe problem]. Please use zen:debug to:
1. Systematically investigate the root cause
2. Document your findings
3. Propose a solution
4. Implement the fix if straightforward
```

#### Using Zen Code Review
```markdown
Please use zen:codereview to analyze the security and quality of:
[Specify files or functionality]

Focus on:
1. Security vulnerabilities
2. Performance concerns
3. Code maintainability
4. Best practice violations
```

#### Using Context7 for Documentation
```markdown
I need to implement [feature]. Please:
1. Use Context7 to find the latest documentation for [framework/library]
2. Identify the recommended approach
3. Implement following best practices from the docs
```

---

## Best Practices & Tips

### For Architects
1. **Be explicit about non-functional requirements**
   - Performance targets
   - Security requirements
   - Scalability needs

2. **Include "Definition of Done" in epics**
   - Code complete
   - Tests written
   - Documentation updated
   - Reviewed and approved

3. **Anticipate integration points**
   - Identify API contracts early
   - Document data formats
   - Specify error handling

### For Tech Leads
1. **Right-size your tasks**
   - 4-8 hours is ideal
   - Never more than 1 day
   - Include buffer for testing

2. **Provide implementation hints**
   - Suggest design patterns
   - Reference existing code
   - Link to documentation

3. **Order tasks logically**
   - Respect dependencies
   - Group related work
   - Enable parallel development

### For Developers

#### Managing Claude Pro Limits
1. **Batch related work**
   - Do all database tasks together
   - Complete full features in one session
   - Group similar refactoring

2. **Optimize context usage**
   ```markdown
   # Instead of:
   "Can you help me with the login endpoint? It should validate email and password..."
   
   # Do this:
   "Implement TASK-002 from .claude/context/current-task.md"
   ```

3. **Know when to reset**
   - Clear context between unrelated features
   - Start fresh for debugging sessions
   - Reset after major refactoring

#### Effective Claude Code Usage
1. **Let Claude Code see your errors**
   - Run tests and share output
   - Execute code and show results
   - Provide stack traces

2. **Be specific about constraints**
   ```markdown
   "Implement this using our existing error handling pattern in src/utils/errors.ts"
   ```

3. **Use iterative development**
   - Start with basic implementation
   - Add features incrementally
   - Refactor after functionality works

#### Session Management
1. **Start each session with context**
   ```bash
   # Beginning of session ritual
   1. Load task document
   2. Review previous session notes
   3. Confirm understanding
   4. Begin implementation
   ```

2. **Document decisions immediately**
   - Why you chose approach A over B
   - Trade-offs accepted
   - Assumptions made

3. **Prepare for handoffs**
   - Stop before hitting limits
   - Create comprehensive notes
   - Test your handoff documentation

### Common Pitfalls to Avoid

1. **Don't dump entire codebases**
   - Claude Code works better with focused context
   - Provide only relevant files

2. **Don't skip documentation**
   - Future you (or teammates) will thank you
   - Handoffs become impossible without notes

3. **Don't ignore Claude's questions**
   - If Claude asks for clarification, provide it
   - Ambiguity wastes tokens and time

4. **Don't fight the token limits**
   - Plan for context management
   - Break work into appropriate chunks

### Success Metrics

Track these to improve your process:
- Tasks completed per session
- Rework required after handoffs
- Time from task start to completion
- Code review feedback quality

---

## Appendix: Quick Reference

### Essential Commands

#### Claude Code Commands
```bash
/reset          # Clear context
/save          # Save current session
/load [file]   # Load context from file
```

#### Useful Zen Tools
```bash
zen:debug       # Systematic debugging
zen:codereview  # Security & quality analysis
zen:refactor    # Code improvement suggestions
zen:analyze     # Architecture assessment
zen:testgen     # Generate comprehensive tests
```

#### Context7 Usage
```bash
# Search documentation
"Use Context7 to find [topic] in [library] docs"

# Get implementation examples
"Check Context7 for [feature] examples in [framework]"
```

### Token-Saving Aliases

Create these shortcuts in your context files:

```markdown
# .claude/context/aliases.md

## Common Patterns
- STANDARD_ERROR_HANDLING: See src/utils/errors.ts
- API_RESPONSE_FORMAT: See src/types/api.ts
- DATABASE_CONVENTIONS: See .claude/context/database-standards.md

## Project Conventions
- TEST_PATTERN: Jest with React Testing Library
- STATE_MANAGEMENT: Zustand stores in src/stores/
- STYLING: Tailwind with custom components
```

Then reference as:
```markdown
"Implement error handling using STANDARD_ERROR_HANDLING pattern"
```

---

## Conclusion

Success with Claude Code in a team environment requires:
1. **Clear structure** - Well-defined phases and responsibilities
2. **Context discipline** - Manage what Claude knows and when
3. **Good documentation** - Persistent knowledge between sessions
4. **Token awareness** - Optimize for Claude Pro limits
5. **Tool mastery** - Leverage MCP servers effectively

Start with this guide, adapt it to your team's needs, and continuously refine based on what works best for your specific use cases.