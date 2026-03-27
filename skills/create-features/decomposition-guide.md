# Feature Decomposition Guide

Reference guide for breaking epics into well-bounded features. Loaded by the create-features skill during decomposition.

---

## Feature Boundary Principles

### 1. Cohesion
A feature groups related functionality that changes together. If modifying one part of the feature frequently requires modifying another part, they belong together.

**Test:** Can you describe what the feature does in one sentence without using "and"? If not, it may be two features.

### 2. Independence
Each feature should be developable, testable, and deliverable without waiting for other features to complete. Features may have ordering preferences, but hard dependencies should be minimized.

**Test:** Could a developer start this feature tomorrow with only the epic context and project conventions? If they need another feature's code first, reconsider the boundary.

### 3. Testability
A feature must have clear acceptance criteria that can be verified. If you can't describe how to test it, the boundary is wrong.

**Test:** Can you write 3-5 concrete acceptance criteria that a developer could verify with commands or manual checks?

### 4. Value Delivery
Each feature should deliver visible value — either to the end user or to the development team. Infrastructure-only features are acceptable when they unblock multiple other features, but should be the exception.

**Test:** After this feature ships, can someone see or use something new? If not, consider merging it with the feature that makes it visible.

---

## Sizing Heuristics

### Target Size
Each feature should decompose into **3-6 tasks of 2-8 hours each**, totaling roughly **12-48 hours of development work**.

### Too Large (split it)
Signals that a feature needs splitting:
- More than 8 acceptance criteria
- Touches more than 3 distinct areas of the codebase
- Would take more than 2 weeks for one developer
- Has internal phases ("first we build X, then we add Y on top")
- Multiple independent user-facing behaviors bundled together

**Splitting strategies:**
- **By user action**: separate CRUD operations (create vs read vs update vs delete)
- **By integration**: separate the core logic from each external integration
- **By depth**: MVP version first, then enhanced version as a follow-up feature
- **By data flow**: separate ingestion from processing from presentation

### Too Small (merge it)
Signals that a feature should be merged with an adjacent one:
- Only 1-2 tasks, each under 2 hours
- Can't be tested independently (only meaningful with another feature)
- Single file change with no distinct acceptance criteria
- Configuration-only change with no behavioral impact

---

## Common Decomposition Patterns

### By Capability
Split by what the system can do. Each feature adds one capability.
```
Epic: User Authentication
  Feature 1: User Registration (sign up flow)
  Feature 2: User Login (sign in + session management)
  Feature 3: Password Reset (forgot/reset flow)
  Feature 4: Social Login (OAuth providers)
```
Best for: user-facing epics with distinct workflows.

### By Entity
Split by the domain object being managed. Each feature handles one entity end-to-end.
```
Epic: Inventory Management
  Feature 1: Product Catalog (CRUD + search)
  Feature 2: Stock Tracking (quantities, locations)
  Feature 3: Supplier Management (vendors, orders)
```
Best for: data-centric epics with distinct domain objects.

### By Integration Point
Split by external system boundary. Each feature handles one integration.
```
Epic: Payment Processing
  Feature 1: Stripe Integration (cards)
  Feature 2: PayPal Integration
  Feature 3: Invoice Generation (PDF + email)
```
Best for: epics that connect to multiple external services.

### By Layer (use sparingly)
Split by technical layer. Use only when layers are independently valuable.
```
Epic: Reporting Dashboard
  Feature 1: Data Pipeline (aggregation + storage)
  Feature 2: API Endpoints (query + filter)
  Feature 3: Dashboard UI (charts + tables)
```
Caution: pure horizontal slices (all backend, then all frontend) often aren't independently deliverable. Prefer vertical slices when possible.

---

## Anti-Patterns to Avoid

### "And" Features
"User login **and** profile management" — these are two features. Split them.

### Infrastructure-Only Features
"Set up database schema" with no user-visible behavior. Merge this into the first feature that uses the schema, or justify it as a foundation that unblocks 3+ features.

### Unbounded Scope
"Improve performance" with no specific criteria. Add concrete targets: "Page load under 2 seconds for product listing with 1000 items."

### Circular Dependencies
Feature A needs Feature B which needs Feature A. Restructure boundaries to break the cycle — usually by extracting the shared piece into its own feature.

### Testing Afterthought
"Add tests for all features" as a separate feature. Testing belongs inside each feature's tasks, not deferred to the end.

---

## Dependency Ordering

After identifying features, order them:

1. **Foundation first**: features that provide shared infrastructure (auth, database, core models)
2. **High-value next**: features that deliver the most user value or reduce the most risk
3. **Independent features in parallel**: features with no dependencies on each other can be assigned to different developers
4. **Enhancement last**: features that improve existing functionality (optimization, polish, edge cases)

For each feature, document:
- **Depends on**: which features must be completed first (hard dependency)
- **Benefits from**: which features make this easier but aren't required (soft dependency)
- **Blocks**: which features are waiting for this one
