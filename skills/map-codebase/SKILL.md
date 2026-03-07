---
user-invocable: true
allowed-tools: Read(*), Glob(*), LS(*), Grep(*), Task(*), Write(*), Bash(mkdir:*)
description: Analyze existing codebase and document patterns
model: sonnet
disable-model-invocation: true
context: fork
---

# Map Codebase

Analyze an existing codebase to understand its structure, patterns, and conventions.
Run this before `/ccmagic:init` on brownfield projects.

## Process

### 1. Create Knowledge Directory

```bash
mkdir -p context/knowledge
```

### 2. Spawn Parallel Analysis Agents

Launch 3 Explore agents in parallel to analyze different aspects of the codebase:

**Agent 1: Stack & Dependencies**
```
Use Task tool with:
  subagent_type: "Explore"
  prompt: |
    # Analyze Technology Stack

    Investigate the technology stack of this codebase.

    ## Areas to Examine
    - **Languages**: Check file extensions, configs, shebang lines
    - **Frameworks**: Look for package.json, requirements.txt, pom.xml, go.mod, Cargo.toml, etc.
    - **Build Tools**: Webpack, Vite, Make, Gradle, npm scripts, etc.
    - **External Services**: API integrations, cloud services, databases
    - **Dev Tools**: Linters, formatters, test frameworks

    ## Output Format
    Write findings to: context/knowledge/STACK.md

    Use this structure:
    ```markdown
    # Technology Stack

    ## Languages
    - [Language]: [version if detectable], [primary use]

    ## Frameworks & Libraries
    ### Core
    - [framework]: [version], [purpose]

    ### Supporting
    - [library]: [purpose]

    ## Build & Dev Tools
    - [tool]: [purpose]

    ## External Services
    - [service]: [how it's used]

    ## Database
    - [database]: [ORM/driver used]

    ## Key Configuration Files
    - [file]: [what it configures]
    ```
```

**Agent 2: Architecture & Structure**
```
Use Task tool with:
  subagent_type: "Explore"
  prompt: |
    # Analyze Architecture

    Investigate the architecture and structure of this codebase.

    ## Areas to Examine
    - **Directory Layout**: How is code organized? (by feature, layer, type)
    - **Entry Points**: Main files, API routes, CLI commands
    - **Key Modules**: Core packages/modules and their responsibilities
    - **Data Flow**: How does data move through the system?
    - **Layering**: Presentation, business logic, data access patterns
    - **Shared Code**: Utilities, common components, shared types

    ## Output Format
    Write findings to: context/knowledge/ARCHITECTURE.md

    Use this structure:
    ```markdown
    # Architecture

    ## Directory Structure
    ~~~
    [tree-like representation of key directories]
    ~~~

    ## Organization Pattern
    [Feature-based / Layer-based / Hybrid - with explanation]

    ## Entry Points
    - [file/route]: [what it handles]

    ## Core Modules
    ### [Module Name]
    - **Location**: [path]
    - **Responsibility**: [what it does]
    - **Dependencies**: [what it uses]

    ## Data Flow
    [Description of how data flows through the system]

    ## Key Patterns
    - [pattern]: [where/how it's used]

    ## Dependency Graph
    [Which modules depend on which]
    ```
```

**Agent 3: Conventions & Patterns**
```
Use Task tool with:
  subagent_type: "Explore"
  prompt: |
    # Analyze Conventions

    Investigate coding conventions and patterns in this codebase.

    ## Areas to Examine
    - **Naming**: Files, functions, variables, classes, constants
    - **Code Style**: Formatting, indentation, quote style
    - **Error Handling**: How are errors caught, logged, propagated?
    - **Testing**: Test file location, naming, patterns, frameworks
    - **Documentation**: JSDoc/docstrings, README patterns, inline comments
    - **Type Safety**: TypeScript strictness, type patterns, any usage

    ## Output Format
    Write findings to: context/knowledge/CONVENTIONS.md

    Use this structure:
    ```markdown
    # Coding Conventions

    ## Naming Conventions
    - **Files**: [pattern, e.g., kebab-case, PascalCase]
    - **Functions**: [pattern]
    - **Variables**: [pattern]
    - **Constants**: [pattern]
    - **Components**: [pattern if applicable]

    ## Code Style
    - **Indentation**: [tabs/spaces, size]
    - **Quotes**: [single/double]
    - **Semicolons**: [yes/no]
    - **Line Length**: [limit if enforced]

    ## Error Handling
    [How errors are typically handled]

    ## Testing Patterns
    - **Location**: [where tests live]
    - **Naming**: [test file naming pattern]
    - **Framework**: [test framework used]
    - **Patterns**: [describe/it, test(), etc.]

    ## Documentation Style
    [How code is documented]

    ## Type Patterns
    [TypeScript/type annotation patterns if applicable]

    ## Common Idioms
    - [idiom]: [example]
    ```
```

### 3. Wait for Agents

All three agents should run in parallel by spawning all 3 Task calls in a single message. Wait for all to complete before proceeding to step 4.

### 4. Synthesize Findings

After all agents complete, read the generated files:
- `context/knowledge/STACK.md`
- `context/knowledge/ARCHITECTURE.md`
- `context/knowledge/CONVENTIONS.md`

Create a summary file: `context/knowledge/README.md`

```markdown
# Codebase Knowledge

Generated: [timestamp]

## Quick Reference

**Stack:** [primary language] + [main framework]
**Architecture:** [organization pattern]
**Testing:** [test framework] in [location]

## Key Files
- Entry point: [main entry]
- Config: [key config files]
- Tests: [test directory]

## Getting Started
[Brief guide based on findings]

## Concerns & Tech Debt
[Any issues or concerns identified during analysis]

## Detailed Documentation
- [STACK.md](./STACK.md) - Technology stack details
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Code organization and patterns
- [CONVENTIONS.md](./CONVENTIONS.md) - Coding standards and idioms
```

### 5. Report & Next Steps

```
Codebase mapped successfully!

Knowledge files created in context/knowledge/:
- STACK.md - Technology stack and dependencies
- ARCHITECTURE.md - Code organization and structure
- CONVENTIONS.md - Coding patterns and conventions
- README.md - Quick reference summary

[If concerns found:]
Concerns identified:
- [concern 1]
- [concern 2]

Next steps:
- Run `/ccmagic:init` to set up project structure
- Or `/ccmagic:plan` to start planning features
- Review knowledge files to familiarize with codebase
```

## Notes

- Designed for brownfield (existing) codebases
- Agents run in parallel for efficiency
- Creates persistent knowledge base for reference
- Run once per project, update manually as needed
- Knowledge files help new team members onboard
