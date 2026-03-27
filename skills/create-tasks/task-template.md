## Task File Template

Each task file follows this structure. Replace bracketed placeholders with actual values.

```markdown
# Task [EPIC]-[FEATURE]-[SEQ]: [Title]

## Parent
- **Epic**: [epic-id] -- [epic name]
- **Feature**: [feature-id] -- [feature name]

## Description
[1-3 sentences describing what this task accomplishes. Focus on the outcome, not the implementation steps. Should answer: "What will be different when this is done?"]

## Scope
**In scope:**
- [Specific deliverable 1]
- [Specific deliverable 2]

**Out of scope:**
- [Thing that might seem related but belongs to another task]

## Acceptance Criteria
- [ ] [Criterion 1 -- specific, testable statement]
- [ ] [Criterion 2 -- observable behavior or artifact]
- [ ] [Criterion 3 -- edge case or error handling]
- [ ] All existing tests pass
- [ ] No linting errors introduced

## Verification
[Machine-runnable commands that return exit code 0 on success]

<verify>[command for criterion 1]</verify>
<verify>[command for criterion 2]</verify>
<verify>[command for criterion 3]</verify>
<verify>[test suite command]</verify>

## Done When
<done>
- [Completion state 1 -- observable behavior]
- [Completion state 2 -- observable behavior]
- [All existing tests pass]
</done>

## Implementation Notes
[Guidance from codebase exploration -- patterns to follow, files to modify, utilities to reuse]

- **Pattern to follow**: [reference existing file/pattern]
- **Files to modify**: [list specific files]
- **Utilities available**: [shared helpers, existing abstractions]
- **Watch out for**: [gotchas discovered during exploration]

## Dependencies
- **Blocked by**: [task-id(s) that must complete first, or "none"]
- **Blocks**: [task-id(s) that cannot start until this completes, or "none"]
- **Parallel group**: [group number -- tasks in same group can run simultaneously]

## Estimated Time
[N] hours
```

---

## Verify Block Examples by Task Type

### API Endpoint Task
```xml
<!-- Health/existence check -->
<verify>curl -sf http://localhost:3000/api/health | jq -e '.status == "ok"'</verify>

<!-- CRUD operations -->
<verify>curl -sf -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@test.com","name":"Test"}' | jq -e '.id'</verify>
<verify>curl -sf http://localhost:3000/api/users | jq -e '.data | length > 0'</verify>

<!-- Error handling -->
<verify>curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/users/nonexistent | grep -q "404"</verify>

<!-- Auth-protected endpoint -->
<verify>curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/api/admin | grep -q "401"</verify>
```

### Database Migration Task
```xml
<!-- Migration applied -->
<verify>npx prisma migrate status 2>&1 | grep -q "applied"</verify>

<!-- Table/column exists -->
<verify>npx prisma db execute --stdin <<< "SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='email'" | grep -q "email"</verify>

<!-- Reversible migration -->
<verify>npx prisma migrate reset --force 2>&1 | grep -q "successfully"</verify>

<!-- Types generated -->
<verify>npx prisma generate 2>&1 | grep -q "Generated Prisma Client"</verify>
```

### UI Component Task
```xml
<!-- Component exists -->
<verify>test -f src/components/LoginForm.tsx</verify>

<!-- Component renders without error -->
<verify>npm test -- --testPathPattern="LoginForm" 2>&1 | grep -q "passed"</verify>

<!-- Build succeeds -->
<verify>npm run build 2>&1 | tail -1 | grep -qv "error"</verify>

<!-- Exports correctly -->
<verify>grep -q "export.*LoginForm" src/components/LoginForm.tsx</verify>

<!-- Accessibility -->
<verify>grep -q "aria-label\|role=" src/components/LoginForm.tsx</verify>
```

### Configuration Change Task
```xml
<!-- Config file updated -->
<verify>grep -q "DATABASE_URL" .env.example</verify>

<!-- Config loads without error -->
<verify>node -e "require('./src/config'); console.log('ok')" 2>&1 | grep -q "ok"</verify>

<!-- Type checking passes -->
<verify>npx tsc --noEmit 2>&1 | grep -qE "^$|no errors"</verify>
```

### Test Writing Task
```xml
<!-- Tests exist -->
<verify>find src -name "*.test.*" -path "*auth*" | wc -l | grep -q "[1-9]"</verify>

<!-- Tests pass -->
<verify>npm test -- --testPathPattern="auth" 2>&1 | grep -q "passed"</verify>

<!-- Coverage threshold met -->
<verify>npm run test:coverage -- --collectCoverageFrom="src/auth/**" 2>&1 | grep -qE "Stmts\s*\|\s*[8-9][0-9]\.|100"</verify>
```

### Documentation Task
```xml
<!-- File exists with content -->
<verify>test -s docs/api-reference.md</verify>

<!-- Required sections present -->
<verify>grep -q "## Authentication" docs/api-reference.md</verify>
<verify>grep -q "## Error Codes" docs/api-reference.md</verify>

<!-- No broken internal links -->
<verify>grep -oP '\[.*?\]\(((?!http).*?)\)' docs/api-reference.md | while read link; do test -f "docs/$link" || exit 1; done</verify>
```

### Refactoring Task
```xml
<!-- Old pattern removed -->
<verify>! grep -r "legacyHelper" src/ 2>/dev/null | grep -q "."</verify>

<!-- New pattern in use -->
<verify>grep -r "newHelper" src/ | wc -l | grep -q "[1-9]"</verify>

<!-- All tests still pass -->
<verify>npm test 2>&1 | grep -q "passed"</verify>

<!-- No type errors -->
<verify>npx tsc --noEmit 2>&1 | grep -qE "^$|no errors"</verify>
```

---

## Done Criteria Examples

### API Endpoint
```xml
<done>
- POST /api/users creates a user and returns 201 with user object
- GET /api/users returns paginated list with 200
- GET /api/users/:id returns single user or 404
- Invalid input returns 400 with validation errors
- All endpoints require authentication (401 without token)
- Unit and integration tests pass
</done>
```

### Database Migration
```xml
<done>
- Users table exists with id, email, name, password_hash, created_at columns
- Email column has unique constraint
- Migration is reversible (down migration drops table)
- Prisma client regenerated with User type
- Seed data script works against new schema
- All existing tests pass with new schema
</done>
```

### UI Component
```xml
<done>
- LoginForm renders email and password fields
- Submit button disabled until both fields have values
- Shows validation errors for invalid email format
- Shows server error message on failed login
- Redirects to dashboard on successful login
- Component tests cover happy path and error states
- Accessible (proper labels, keyboard navigation, ARIA attributes)
</done>
```

### Configuration
```xml
<done>
- Environment variables documented in .env.example
- Config module exports typed configuration object
- Missing required vars throw descriptive error at startup
- Default values set for optional vars
- Config validation runs on application boot
</done>
```
