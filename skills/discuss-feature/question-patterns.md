# Question Patterns by Feature Type

Adaptive question templates organized by feature type. Select questions relevant to the gray areas identified during codebase exploration. Skip questions already answered by the feature overview or existing patterns.

## API Features

### Architecture
- How should endpoints be organized? (resource-based routes, RPC-style, GraphQL mutations)
- What authentication/authorization model applies? (JWT, session, API key, OAuth scope)
- Should this use the existing controller pattern or introduce a new one?
- Request validation approach? (middleware, schema validation library, manual)

### Data
- What is the primary data model? (new table, extend existing, view/aggregation)
- How should relationships be modeled? (foreign keys, embedded, lookup table)
- What indexes are needed for expected query patterns?
- Migration strategy? (additive only, requires data backfill, breaking schema change)

### Behavior
- Error response format? (follow existing pattern, custom error codes, RFC 7807)
- Pagination approach? (cursor, offset, keyset -- what does the codebase use?)
- Rate limiting needed? (per-user, per-endpoint, global)
- Idempotency requirements? (safe retries, idempotency keys)

### Scope
- Which HTTP methods are needed for MVP? (full CRUD or subset)
- Should filtering/sorting/search be included now or deferred?
- Webhook/event emission needed when resources change?
- API versioning strategy if this is a new surface area?

## UI Features

### Architecture
- Component structure? (single component, page + subcomponents, feature module)
- State management approach? (local state, context, global store, server state)
- Should this follow the existing page/component pattern or introduce a new one?
- Routing approach? (new route, nested route, modal overlay, tab within existing page)

### Data Flow
- How does data reach the UI? (REST call, GraphQL query, WebSocket, SSE)
- Caching strategy? (SWR/React Query, manual cache, no cache)
- Optimistic updates needed? (instant feedback vs wait for server)
- Form handling approach? (controlled, uncontrolled, form library)

### User Experience
- Loading states? (skeleton, spinner, progressive)
- Error states? (inline, toast, error boundary, retry button)
- Empty states? (illustration, call-to-action, placeholder content)
- Responsive behavior? (mobile-first, desktop-only, adaptive breakpoints)

### Scope
- Accessibility requirements? (WCAG level, screen reader support, keyboard navigation)
- Animation/transitions needed? (page transitions, micro-interactions)
- Internationalization needed now or deferred?
- Dark mode / theming considerations?

## Data Migration Features

### Strategy
- Migration approach? (online/zero-downtime, maintenance window, blue-green)
- Rollback plan? (reversible migration, backup/restore, forward-fix only)
- Data volume considerations? (batch processing, streaming, chunked)
- Existing data transformation rules? (mapping old to new, default values, nullability)

### Validation
- Data validation before migration? (pre-check script, dry-run mode)
- How to handle invalid/corrupt existing data? (skip, fix, quarantine, fail)
- Referential integrity across tables? (order of operations, foreign key constraints)
- Verification after migration? (row counts, checksums, spot checks)

### Coordination
- Which services depend on the schema being migrated? (downtime coordination)
- Can the migration run alongside the old schema? (dual-write period)
- Backfill strategy for computed or derived columns?
- Index creation timing? (during migration, after, concurrent)

### Scope
- Is this a one-time migration or a repeatable process?
- Should migration tooling be reusable for future migrations?
- Monitoring during migration? (progress, error rate, performance impact)
- Cleanup of old schema/data after migration confirms success?

## Integration Features

### Connection
- Authentication with external service? (API key, OAuth, mTLS, webhook secret)
- SDK or raw HTTP? (official SDK available, REST client, GraphQL client)
- Connection pooling or singleton client? (what does the codebase do?)
- Configuration approach? (env vars, config file, secrets manager)

### Reliability
- Failure handling? (retry with backoff, circuit breaker, fallback, queue for later)
- Timeout values? (connect timeout, read timeout, overall deadline)
- Rate limit handling? (respect headers, preemptive throttling, queue)
- Monitoring? (health check, latency tracking, error rate alerting)

### Data Flow
- Sync or async communication? (request/response, event-driven, webhook)
- Data mapping between systems? (direct mapping, transformation layer, adapter)
- Conflict resolution? (last write wins, merge, manual review)
- Payload validation? (schema validation on incoming data, strict/lenient parsing)

### Scope
- Which operations need integration for MVP? (read-only, full sync, subset)
- Webhook handling needed? (receive, verify, process, acknowledge)
- Should the integration be behind a feature flag?
- Testing approach? (mock service, sandbox environment, contract tests)

## Infrastructure Features

### Architecture
- Deployment model? (container, serverless, VM, edge)
- Configuration management? (env vars, config service, feature flags)
- Secret management? (vault, cloud secrets manager, env file)
- Scaling approach? (horizontal auto-scale, vertical, fixed capacity)

### Operations
- Monitoring approach? (metrics, logs, traces, health endpoints)
- Alerting rules? (error rate, latency, resource usage thresholds)
- Rollback procedure? (blue-green, canary, instant rollback, manual)
- Backup strategy? (automated, frequency, retention, restore tested)

### Security
- Network boundaries? (VPC, security groups, firewall rules)
- Access control? (IAM roles, service accounts, least privilege)
- Encryption requirements? (at rest, in transit, key management)
- Audit logging? (who did what, compliance requirements)

### Scope
- Is this greenfield infrastructure or modifying existing?
- Should this be codified as IaC? (Terraform, Pulumi, CloudFormation)
- Documentation requirements? (runbooks, architecture diagrams)
- Disaster recovery scope? (RPO/RTO targets, multi-region)

## Cross-Cutting Questions (Apply to All Types)

### Testing
- What test types are needed? (unit, integration, e2e, contract)
- Should tests follow the existing pattern in the codebase?
- Test data approach? (factories, fixtures, builders, inline)
- Coverage expectations? (match existing, specific threshold)

### Error Handling
- How should errors be categorized? (user error, system error, external error)
- Logging level for different error types?
- Should errors propagate or be caught at specific boundaries?
- User-facing error messages? (generic, specific, actionable)

### Performance
- Are there latency requirements? (p50, p99, hard SLA)
- Expected load? (requests/sec, concurrent users, data volume)
- Caching appropriate? (what layer, TTL, invalidation)
- Should performance testing be part of acceptance criteria?

## Usage Notes

- Select 3-8 questions total, not the entire list for a feature type
- Prioritize questions where codebase exploration revealed ambiguity
- Skip questions where the existing codebase has a clear, consistent pattern
- Present codebase evidence alongside each question to help the user decide
- If a question has an obvious answer from the codebase, state the recommendation and ask for confirmation rather than presenting it as an open question
