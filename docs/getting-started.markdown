# Getting Started with ccmagic

This guide will help you get started with the ccmagic custom commands collection for Claude Code.

## Prerequisites

- Claude Code installed and configured
- Git for cloning the repository

## Installation Steps

1. Navigate to your Claude commands directory:
   ```bash
   cd ~/.claude/commands/
   ```

2. Clone the ccmagic repository:
   ```bash
   git clone https://github.com/[your-username]/ccmagic.git
   ```

3. Verify installation by listing available commands in Claude Code:
   ```
   /help
   ```
   
   You should see commands prefixed with `ccmagic:` in the list.

## First Command

Try the example command:
```
/ccmagic:example Hello World
```

## Understanding Command Structure

Each command is a Markdown file with:
- **Filename**: Becomes the command name
- **Frontmatter**: Optional configuration
- **Body**: The prompt template

## Next Steps

- Browse existing commands in the repository
- Create your own custom commands
- Share useful commands with the community