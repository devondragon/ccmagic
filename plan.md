---
allowed-tools: Write(*), Read(*), Bash(mkdir -p:*), Bash(mkdir:*), Bash(touch:*)
description: Interactive project planning session to define scope and generate technical requirements
argument-hint: [project-type or domain]
model: claude-opus-4-1-20250805
---

# Project Planning Session

I'll help you define the scope and technical requirements for your project. This is an interactive process where I'll:

1. Ask clarifying questions about your project
2. Help define the business value and goals
3. Identify technical constraints and requirements
4. Generate a comprehensive technical requirements document
5. Suggest initial epics based on our discussion

## Initial Context Gathering

First, let me understand your project better. Please tell me:

### Core Questions:
1. **What are we building?** (e.g., SaaS app, API, mobile app, internal tool)
2. **Who is the primary user/customer?**
3. **What problem does this solve?**
4. **What's your timeline?** (MVP date, milestones)
5. **Team size and composition?**

### Technical Context:
6. **Preferred tech stack?** (or should I recommend one?)
7. **Any existing systems to integrate with?**
8. **Deployment target?** (cloud provider, on-prem, etc.)
9. **Expected scale?** (users, requests, data volume)
10. **Security/compliance requirements?**

$ARGUMENTS

---

Based on your answers, I will:

## Generate Documentation Structure
Creates standard CCMagic structure with:
- Core context files (project.md, conventions.md, working-state.md, backlog.md)
- Knowledge base (technical-requirements.md, business-requirements.md, architecture.md)
- Epics directory with initial epics based on requirements
- Features directory with epic-XXX-fNN-name/ structure
- Spikes directory for research tasks
- Sessions/handoffs for documentation

## Files I'll Create

1. **`/context/knowledge/technical-requirements.md`**:
   - Project overview
   - Success criteria
   - Technical architecture
   - Non-functional requirements
   - Constraints and assumptions
   - Risk assessment

2. **`/context/knowledge/business-requirements.md`**:
   - Business goals
   - User stories
   - Success metrics
   - MVP definition

3. **`/context/knowledge/architecture.md`**:
   - System design patterns
   - Technology decisions
   - Data flow diagrams
   - Component relationships

4. **Initial epics in `/context/epics/`**:
   - `epic-001-infrastructure.md` - Core infrastructure setup
   - `epic-002-authentication.md` - User authentication (if needed)
   - `epic-003-core-features.md` - Core business logic
   - Additional epics based on requirements

5. **Feature directories in `/context/features/`**:
   - Format: `epic-XXX-fNN-name/` with overview.md, working-state.md, tasks/

6. **Update core context files**:
   - `/context/project.md` - Project vision and tech stack
   - `/context/conventions.md` - Coding standards for chosen stack
   - `/context/working-state.md` - Initial sprint planning
   - `/context/backlog.md` - Captured ideas from planning session

## Interactive Planning Process

This is a collaborative session. I'll:
- Ask follow-up questions for clarity
- Suggest best practices based on your requirements
- Identify potential challenges early
- Ensure we have enough detail for the next phase

After this planning session, you'll be ready to:
- Use `/create-features` to break down epics into features
- Use `/create-tasks` to generate specific tasks within features
- Use `/start` to begin development with clear direction
- Track progress in feature-specific `working-state.md` files

## Note for Solo Developers / Simple Projects

For simpler projects, we'll start with a minimal structure:
- One epic: `epic-001-mvp`
- One feature: `epic-001-f01-core`
- Focus on tasks within that single feature
- Expand to more epics/features only as complexity grows

This keeps things simple while maintaining room for growth!

Let's start the planning conversation!
