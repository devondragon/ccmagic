---
allowed-tools: Write(*), Read(*), Bash(git:*), Glob(*), LS(*), TodoWrite(*), mcp__zen__thinkdeep(*), mcp__zen__analyze(*), Task(*), Bash(mv:*)
description: Start working on a research spike or investigation task
argument-hint: spike-id (optional, e.g., spike-001 or spike-001-research-auth)
model: opus
---

# Start Spike and Begin Investigation

## Implementation Plan

This command will:

### 1. **Spike Selection & Validation:**
- If spike-id provided: Locate in `context/spikes/todo/`
- If no spike-id: List available spikes and ask user to choose
- Move spike from `todo/` to `current/` directory
- Validate no other spike is currently active

### 2. **Git Branching:**
- **Research Branch**: `spike/[spike-id]-[description]`
- **Direct commit**: For quick investigations


### 3. **Update Working State:**
Update project working-state.md:

```markdown
## Current Spike
- **ID**: spike-001-research-auth-providers
- **Type**: Research / Investigation
- **Branch**: spike/spike-001-research-auth-providers
- **Started**: 2024-01-15 14:30

## Investigation Focus
- Evaluating authentication provider options
- Comparing OAuth vs JWT approaches
```

### 4. **Begin Investigation Work:**

#### Load Context (in order):
1. `/context/project.md` - Project overview
2. `/context/conventions.md` - Development conventions
3. `/context/working-state.md` - Current project state
4. `/context/spikes/current/[spike-file].md` - Spike details

Note: CLAUDE.md is automatically loaded. Only load specific knowledge files as needed during investigation.

#### Investigation Workflow:

**If zen MCP tools are available:**
1. Use `mcp__zen__thinkdeep` (model: gemini-2.5-pro or best available) to:
   - Analyze the research questions
   - Create investigation plan
   - Identify information sources

2. Use `TodoWrite` to track investigation steps

3. Use `mcp__zen__analyze` for:
   - Architecture analysis
   - Performance evaluations
   - Security assessments
   - Code quality reviews

4. For complex research needing multiple perspectives:
   - Use `Task` tool with general-purpose agent

**If zen MCP tools are NOT available:**
1. Analyze research questions using standard Claude model
2. Create investigation plan manually
3. Document findings systematically
4. Perform analysis and comparisons

#### Key Investigation Guidelines:
- **Document findings**: Update spike file with discoveries
- **Create artifacts**: Save useful code snippets, configs, or examples
- **Update knowledge base**: Transfer learnings to `/context/knowledge/`
- **Make recommendations**: Provide clear, actionable conclusions

### 5. **Spike Completion:**
When investigation is complete:
- Move spike from `current/` to `completed/`
- Update working-state.md
- Document key findings in knowledge base
- Create follow-up tasks if implementation is needed

## Spike Types and Approaches:

### Research Spikes
- Technology evaluation
- Framework comparison
- Best practices investigation
- Use: Web search, documentation review, proof-of-concepts

### Technical Spikes
- Performance testing
- Security analysis
- Integration feasibility
- Use: Code experiments, benchmarks, test implementations

### Architecture Spikes
- Design pattern evaluation
- System design exploration
- Scalability analysis
- Use: Diagrams, prototypes, analysis tools

## Output Format:
Produces findings, recommendations, next steps, and artifacts in completed spike file.

## Notes:
- Only one spike should be active at a time
- Document everything - negative results are valuable too
- Create tasks for actual implementation work
