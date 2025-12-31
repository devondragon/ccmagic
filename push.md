# Push Command

Intelligently commit all changes in logical groups with detailed conventional commit messages, then push to remote.

## Process Overview

1. **Analyze Changes**: Review all staged and unstaged changes
2. **Check for Sensitive Files**: Identify files that may not belong in the repo
3. **Group Logically**: Organize changes into semantic commit groups
4. **Commit Each Group**: Create commits with detailed conventional messages
5. **Pre-Push Safety**: Check upstream status before pushing
6. **Push**: Send all commits to remote

## Step 1: Gather Current State

```bash
# Get all changes
git status --porcelain

# Get detailed diff for analysis
git diff --name-status

# Get staged changes separately
git diff --cached --name-status

# Check current branch
git branch --show-current
```

## Step 2: Sensitive File Detection

Check for files that might not belong in version control and should prompt the user:

### Always Ask About
- `.claude/settings*` - Claude Code settings (may contain personal preferences)
- `.env*` files (except `.env.example`)
- `*credentials*`, `*secrets*`, `*keys*` files
- `*.pem`, `*.key`, `*.p12`, `*.pfx` - certificates/keys
- `*token*` files
- `config/*.local.*` - local config overrides
- IDE settings not in .gitignore (`.idea/`, `.vscode/settings.json`)

### Check User Preferences

Before asking, check if user has previously answered for this file pattern:

```bash
# Check for saved preferences
if [ -f "context/commit-preferences.md" ]; then
    # Load saved include/exclude patterns
    cat context/commit-preferences.md
fi
```

### Preference Storage Format

If `context/` directory exists, save preferences to `context/commit-preferences.md`:

```markdown
# Commit Preferences

## Always Include
- .vscode/extensions.json

## Always Exclude
- .claude/settings.local.json

## Last Updated
2024-01-15
```

**Important**: When user answers a sensitive file question, ask if they want to remember this choice for future commits. If yes, update `context/commit-preferences.md`.

## Step 3: Logical Grouping Strategy

Analyze changes and group by semantic relationship:

### Grouping Heuristics

1. **By Feature/Component**
   - Files in same directory often relate
   - Import/export relationships indicate coupling
   - Test files group with their implementation

2. **By Change Type**
   - New features (`feat:`)
   - Bug fixes (`fix:`)
   - Documentation (`docs:`)
   - Configuration (`chore:`)
   - Refactoring (`refactor:`)
   - Tests (`test:`)
   - Styles (`style:`)
   - Performance (`perf:`)
   - Build/CI (`build:`, `ci:`)

3. **By Impact Scope**
   - Breaking changes should be isolated
   - Related config + code changes together
   - Migration files with schema changes

### Grouping Rules

- **Single Responsibility**: Each commit should represent one logical change
- **Atomic**: Each commit should leave the codebase in a working state
- **Reviewable**: Groups should be easy to understand in code review
- **Bisectable**: Changes should support `git bisect` for debugging

### Example Groupings

```
Group 1 (feat): New user authentication
  - src/auth/login.ts
  - src/auth/logout.ts
  - src/auth/types.ts
  - tests/auth/login.test.ts

Group 2 (chore): Update dependencies
  - package.json
  - package-lock.json

Group 3 (docs): Update API documentation
  - docs/api.md
  - README.md
```

## Step 4: Commit Message Format

Use conventional commits with detailed bodies:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type Prefixes
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes nor adds
- `perf`: Performance improvement
- `test`: Adding/updating tests
- `build`: Build system or dependencies
- `ci`: CI configuration
- `chore`: Other changes (configs, etc.)

### Message Quality Guidelines

**Subject Line**:
- Imperative mood ("add" not "added")
- No period at end
- Max 72 characters
- Clear and specific

**Body** (when needed):
- Explain *what* and *why*, not *how*
- Wrap at 72 characters
- Include context for future readers

**Footer** (when applicable):
- Breaking changes: `BREAKING CHANGE: description`
- Issue references: `Closes #123`, `Fixes #456`
- Co-authors: `Co-authored-by: Name <email>`

### Example Commit Message

```
feat(auth): add JWT token refresh mechanism

Implement automatic token refresh to prevent session expiration during
active use. Tokens are refreshed 5 minutes before expiration.

- Add refresh token endpoint handler
- Implement client-side token refresh interceptor
- Store refresh tokens securely in httpOnly cookies

Closes #234
```

## Step 5: Pre-Push Safety Checks

Before pushing, verify remote status:

```bash
# Fetch latest remote state
git fetch origin

# Get current branch
BRANCH=$(git branch --show-current)

# Check if upstream exists
if ! git rev-parse --abbrev-ref @{upstream} 2>/dev/null; then
    echo "No upstream branch. Will create with: git push -u origin $BRANCH"
    # Ask user to confirm creating upstream
fi

# Check if behind remote
BEHIND=$(git rev-list --count HEAD..origin/$BRANCH 2>/dev/null || echo "0")
if [ "$BEHIND" -gt 0 ]; then
    echo "⚠️ Your branch is $BEHIND commits behind origin/$BRANCH"
    echo "Recommend: pull/rebase before pushing to avoid conflicts"
    # Ask user: pull now, rebase now, or push anyway?
fi

# Check if ahead
AHEAD=$(git rev-list --count origin/$BRANCH..HEAD 2>/dev/null || echo "0")
echo "You have $AHEAD commits to push"
```

### Pre-Push Options

When behind remote, offer choices:
1. **Pull and merge**: `git pull origin $BRANCH`
2. **Rebase**: `git pull --rebase origin $BRANCH`
3. **Push anyway**: Proceed (may be rejected by remote)
4. **Abort**: Cancel the push operation

## Step 6: Execute Push

```bash
# Push with upstream tracking if needed
if git rev-parse --abbrev-ref @{upstream} 2>/dev/null; then
    git push
else
    git push -u origin $(git branch --show-current)
fi
```

## User Interaction Points

The command should ask the user at these points:

1. **Sensitive files detected**: "Should [filename] be committed? (yes/no/always/never)"
   - `always`: Add to preferences as always include
   - `never`: Add to preferences as always exclude

2. **Behind remote**: "Branch is X commits behind. Pull first? (merge/rebase/skip/abort)"

3. **No upstream**: "No upstream branch exists. Create origin/[branch]? (yes/no)"

## Error Handling

### Common Issues

1. **Nothing to commit**: Report "No changes to commit" and exit
2. **Push rejected**: Suggest pull/rebase and retry
3. **Protected branch**: Warn and abort, suggest PR workflow
4. **Hook failures**: Show hook output, ask to retry or skip

### Recovery

If any step fails:
- Report clear error message
- Suggest recovery action
- Do not leave repo in inconsistent state

## Output Format

Provide clear progress updates:

```
📋 Analyzing changes...
   Found 12 modified files, 3 new files, 1 deleted

🔍 Checking for sensitive files...
   ⚠️  Found: .claude/settings.json
   → Should this be committed? (Recommended: no for personal settings)

📦 Grouping into logical commits...
   Group 1: feat(api): add user profile endpoints (4 files)
   Group 2: test(api): add profile endpoint tests (2 files)
   Group 3: docs: update API documentation (3 files)
   Group 4: chore: update dependencies (2 files)

✏️  Creating commits...
   ✓ feat(api): add user profile endpoints
   ✓ test(api): add profile endpoint tests
   ✓ docs: update API documentation
   ✓ chore: update dependencies

🔄 Checking remote status...
   Branch: feature/user-profiles
   Remote: up to date

🚀 Pushing to origin...
   ✓ Pushed 4 commits to origin/feature/user-profiles

✅ Complete! 4 commits pushed successfully.
```

## Integration with CCMagic

- Check for `context/` directory for preference storage
- Respect `context/conventions.md` if it specifies commit message conventions
- Update `context/working-state.md` after successful push if it exists

## Execution

Begin immediately by analyzing the current git status. Ask questions only for sensitive files and pre-push decisions. Proceed efficiently through the commit and push process. Provide clear progress feedback throughout.
