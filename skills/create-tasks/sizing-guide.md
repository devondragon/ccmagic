## Task Sizing Guide

Target: every task should take **2-8 hours** of focused development work.

---

### Signals a Task is Too Large (> 8 hours)

| Signal | Example | Action |
|--------|---------|--------|
| Acceptance criteria span multiple subsystems | "API returns data AND UI renders it AND migration adds column" | Split by layer |
| More than 5 acceptance criteria | 7+ checkboxes in one task | Group related criteria into separate tasks |
| Description uses "and" for unrelated work | "Set up auth AND configure email AND add rate limiting" | One task per concern |
| Multiple files across different layers | Controller + model + migration + component + test | Split by layer |
| Estimated over 8 hours | Complex feature with many moving parts | Find a natural seam |
| Multiple new abstractions needed | New service + new middleware + new utility | One abstraction per task |
| Requires learning + implementing | "Research best approach AND build it" | Spike first, then implement |

### Signals a Task is Too Small (< 2 hours)

| Signal | Example | Action |
|--------|---------|--------|
| Single line change | "Update version number in config" | Combine with adjacent task |
| No independent verification | "Add import statement" | Part of the task that uses the import |
| Under 30 minutes of work | "Create empty directory structure" | Combine into setup task |
| No acceptance criteria beyond "exists" | "Create placeholder file" | Merge with the task that fills it |
| Trivially done inside another task | "Export the function" when another task writes it | Merge |

---

### Splitting Strategies

#### Split by Architectural Layer
Best for full-stack features. Each layer becomes its own task:

```
Original: "Add user registration"

Split:
  Task 001: Database schema -- users table, migration, Prisma types
  Task 002: API endpoint -- POST /api/users, validation, error handling
  Task 003: UI component -- RegistrationForm, client validation, submit flow
  Task 004: Integration tests -- end-to-end registration flow
```

**When to use:** Feature touches 3+ architectural layers.

#### Split by User Capability (CRUD)
Best for resource management features:

```
Original: "Build user management"

Split:
  Task 001: Create user (POST endpoint + form)
  Task 002: Read/list users (GET endpoints + list view)
  Task 003: Update user (PUT endpoint + edit form)
  Task 004: Delete user (DELETE endpoint + confirmation)
```

**When to use:** Feature involves multiple operations on the same resource.

#### Split by Integration Boundary
Best for features connecting to external systems:

```
Original: "Add payment processing"

Split:
  Task 001: Internal payment model and business logic
  Task 002: Stripe API integration (adapter pattern)
  Task 003: Webhook handler for payment events
  Task 004: Payment UI and checkout flow
```

**When to use:** Feature has clear internal vs external boundaries.

#### Split by Complexity Phase
Best for features requiring incremental sophistication:

```
Original: "Add search functionality"

Split:
  Task 001: Basic exact-match search
  Task 002: Fuzzy matching and relevance scoring
  Task 003: Search filters and facets
  Task 004: Search result caching and performance
```

**When to use:** Feature has a natural simple-to-complex gradient.

#### Extract Setup/Infrastructure
Best when multiple tasks share a prerequisite:

```
Original: Tasks 1-5 all need a test database

Split:
  Task 000: Set up test database, fixtures, and test utilities
  Tasks 001-005: Each assumes test infrastructure exists
```

**When to use:** 2+ tasks share infrastructure that does not exist yet.

---

### Dependency Identification Patterns

#### Always Creates a Dependency

| Upstream task | Downstream task | Why |
|---------------|----------------|-----|
| Database migration | Any task reading/writing that table | Schema must exist |
| Shared utility/helper | Any task importing it | Code must exist to import |
| API endpoint | UI component consuming it | Endpoint must exist to call |
| Auth/middleware | Protected routes | Auth must work first |
| Config/environment setup | Anything using that config | Config must load |
| Type definitions | Anything using those types | Types must compile |

#### Never Creates a Dependency

| Task A | Task B | Why independent |
|--------|--------|----------------|
| UI component A | UI component B (no shared state) | No data flow between them |
| API endpoint A | API endpoint B (no shared model) | Independent resources |
| Docs for feature A | Docs for feature B | Pure documentation |
| Test for module A | Test for module B | Independent test suites |

#### Conditional Dependency (Check Carefully)

| Scenario | Dependent if... | Independent if... |
|----------|-----------------|-------------------|
| Two API endpoints | They share a model or service | They use separate models |
| Two UI components | One renders inside the other | They appear on different pages |
| Test task and feature task | Tests need the feature built first | Tests are written as TDD (before feature) |
| Refactoring and new feature | New feature builds on refactored code | Refactoring is isolated module |

---

### Parallel Work Patterns

Tasks can be worked on simultaneously when they have:
- **No shared files** -- different tasks modify different files
- **No data dependency** -- one does not read what another writes
- **No import dependency** -- one does not import from another
- **Independent verification** -- each can be verified without the other

#### Common Parallel Groups

**Group: Independent API endpoints**
```
Task 003: GET /api/users (reads users table)
Task 004: GET /api/products (reads products table)
-- Parallel: different tables, different controllers
```

**Group: Independent UI components**
```
Task 005: Header component
Task 006: Footer component
-- Parallel: no shared state, different pages sections
```

**Group: Documentation + Implementation**
```
Task 007: Write API documentation
Task 008: Implement internal service logic
-- Parallel: docs describe interface, implementation is internal
```

#### Anti-patterns (Looks Parallel but Is Not)

**Shared database migration:**
```
Task A: Add users table (migration 001)
Task B: Add orders table with user_id FK (migration 002)
-- Sequential: B depends on A's table for foreign key
```

**Shared state management:**
```
Task A: Add auth state to Redux store
Task B: Add user profile component (reads auth state)
-- Sequential: B reads state that A creates
```

**Shared test fixtures:**
```
Task A: Create test helper utilities
Task B: Write tests using those helpers
-- Sequential: B imports from A
```

---

### Estimation Heuristics

| Task type | Typical range | Notes |
|-----------|---------------|-------|
| Database migration + model | 2-3h | Schema design, migration, type generation |
| Single API endpoint (CRUD) | 3-5h | Route, controller, validation, error handling, tests |
| UI component (simple) | 2-4h | Component, styles, basic tests |
| UI component (complex/interactive) | 5-8h | State management, animations, accessibility, tests |
| Integration/E2E tests | 3-5h | Setup, fixtures, test cases, CI config |
| Configuration/setup | 2-3h | Config files, env vars, documentation |
| Refactoring | 3-6h | Find usages, update, verify nothing breaks |
| Documentation | 2-4h | Write, review, add examples |
| External API integration | 4-8h | Client setup, error handling, retry logic, tests |

**Adjustment factors:**
- Unfamiliar codebase: add 30-50%
- No existing patterns to follow: add 20-30%
- Requires coordination with other tasks: add 10-20%
- Well-documented existing pattern: subtract 20%
