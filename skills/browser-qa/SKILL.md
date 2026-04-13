---
description: Systematically QA test a web app in a real browser — find bugs, fix them, verify with screenshots
allowed-tools: Read(*), Write(*), Edit(*), Bash(git:*, curl:*), Glob(*), Grep(*), Agent(*), AskUserQuestion(*), mcp__chrome_devtools__navigate_page(*), mcp__chrome_devtools__take_screenshot(*), mcp__chrome_devtools__take_snapshot(*), mcp__chrome_devtools__evaluate_script(*), mcp__chrome_devtools__resize_page(*), mcp__chrome_devtools__click(*), mcp__chrome_devtools__fill(*), mcp__chrome_devtools__fill_form(*), mcp__chrome_devtools__press_key(*), mcp__chrome_devtools__hover(*), mcp__chrome_devtools__list_console_messages(*), mcp__chrome_devtools__list_network_requests(*), mcp__chrome_devtools__lighthouse_audit(*), mcp__chrome_devtools__wait_for(*)
argument-hint: "[URL] [--quick|--exhaustive] [--scope PAGE]"
model: sonnet
context: fork
---

# Browser QA

Systematically test a web application like a real user — navigate every page, click every button, fill every form, check every state. When you find bugs, fix them in source code with atomic commits and re-verify with before/after screenshots.

> **Browser required:** This skill uses Chrome DevTools MCP for all interactions. If unavailable, it cannot run (there's no meaningful fallback for interactive QA).

## Step 0: Parse Arguments & Setup

| Argument | Description |
|----------|-------------|
| *(empty)* | Auto-detect dev server, or ask for URL |
| `<URL>` | Target URL to test |
| `--quick` | Critical + high severity only, 3-5 pages |
| `--exhaustive` | All severities including cosmetic, full site coverage |
| `--scope PAGE` | Focus on a specific page or flow (e.g., `--scope billing`) |
| `--diff` | Scope to pages affected by current branch changes |

**Tier defaults:**
- **Quick:** Fix critical + high only. Mark medium/low as deferred.
- **Standard (default):** Fix critical + high + medium.
- **Exhaustive:** Fix all, including cosmetic.

### Auto-detect dev server

```bash
for port in 3000 4000 5173 8080 8000; do curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -q "200\|301\|302" && echo "FOUND: http://localhost:$port" && break; done
```

If no server found and no URL given, use `AskUserQuestion` to ask.

### Diff-aware mode

When `--diff` or auto-detected (feature branch, no URL):
1. `git diff main...HEAD --name-only` — find changed files
2. Map changed files to affected routes/pages
3. Test only those pages (plus homepage as a regression check)

### Clean working tree check

```bash
git status --porcelain
```

If dirty, use `AskUserQuestion`:
- A) Commit my changes first, then start QA
- B) Continue without fix loop (report-only, no commits)
- C) Abort

### Verify Chrome DevTools MCP

Try `mcp__chrome_devtools__navigate_page` with the target URL. If the tool errors:
> "Chrome DevTools MCP is unavailable. /browser-qa requires a browser connection to test interactively. Check that Chrome DevTools MCP is configured and a browser is accessible."

Stop — there's no meaningful fallback for interactive QA.

---

## Phase 1: Discovery

Navigate to the target URL and map the application:

1. **Screenshot the landing page** — `mcp__chrome_devtools__take_screenshot`, then Read to show inline
2. **Get the accessibility snapshot** — `mcp__chrome_devtools__take_snapshot` to understand page structure
3. **Discover navigation** — identify all links, nav items, and routes:
   ```js
   JSON.stringify([...document.querySelectorAll('a[href],nav a,[role=link]')].map(a => ({text: a.textContent.trim().slice(0,40), href: a.href})).filter(a => a.href.startsWith(location.origin)).slice(0,30))
   ```
4. **Check console for immediate errors** — `mcp__chrome_devtools__list_console_messages`
5. **Build a site map** — list of pages to test based on discovered links

### Page scope by tier
- **Quick:** Homepage + 2-4 key pages (from primary navigation)
- **Standard:** All navigation targets + key user flows (5-8 pages)
- **Exhaustive:** Every discovered page + deep interaction flows (10-15 pages)

---

## Phase 2: Page-by-Page Testing

For each page in scope:

### 2a. Navigate and baseline

1. `mcp__chrome_devtools__navigate_page` to the page
2. `mcp__chrome_devtools__take_screenshot` — baseline screenshot
3. `mcp__chrome_devtools__list_console_messages` — check for JS errors
4. `mcp__chrome_devtools__list_network_requests` — check for failed requests (4xx, 5xx)

### 2b. Interactive element testing

Get all interactive elements via `mcp__chrome_devtools__take_snapshot` (accessibility tree), then systematically test:

**Buttons:** Click each button. Check for:
- Does something happen? (no dead buttons)
- Any JS errors in console after click?
- Does the UI update as expected?
- Loading states appear and resolve?

**Links:** Click internal links. Check for:
- Navigation works (URL changes)
- No 404s
- Back button works after navigation

**Forms:** For each form on the page:
1. Submit empty — check validation messages appear
2. Fill with valid data using `mcp__chrome_devtools__fill` — submit — check success
3. Fill with edge cases (very long strings, special characters, SQL-like input) — check no crashes
4. Check required field indicators are present

**Dropdowns/Selects:** Open each, verify options render, select an option, verify state updates.

**Modals/Dialogs:** Trigger each modal. Check: renders correctly, can be dismissed (X button, escape key, backdrop click), form inside modal works.

### 2c. State testing

- **Empty states:** Navigate to pages that might have no data. Check for a useful empty state (not blank screen or raw error).
- **Error states:** If possible, trigger errors (invalid input, broken URLs). Check for helpful error messages.
- **Loading states:** Note any visible loading spinners or skeletons. Check they resolve.

### 2d. Responsive check

For each page:
1. `mcp__chrome_devtools__resize_page` to 375 (mobile) — screenshot
2. Check: no horizontal scroll, touch targets >= 44px, navigation collapses, text readable
3. `mcp__chrome_devtools__resize_page` to 768 (tablet) — screenshot
4. `mcp__chrome_devtools__resize_page` to 1440 (desktop) — restore

---

## Phase 3: User Flow Testing

Walk 2-4 key user flows end-to-end (the most important things a user would do):

For each flow:
1. Start from the entry point
2. Perform each step (click, fill, submit, navigate)
3. Screenshot at each major step
4. Verify the expected outcome at the end
5. Check the whole flow works without console errors

**Common flows to test** (select based on what the app does):
- Sign up / login / logout
- Create something (post, project, item)
- Edit and save
- Delete with confirmation
- Search and filter
- Checkout / payment (if applicable)
- Settings change

---

## Phase 4: Performance & Accessibility Quick Check

1. `mcp__chrome_devtools__lighthouse_audit` on the homepage — extract:
   - Performance score
   - LCP, CLS, FID/INP
   - Accessibility score
   - Any critical accessibility issues

2. Flag performance issues as QA findings if:
   - LCP > 3s (critical)
   - LCP > 2s (medium)
   - CLS > 0.25 (high)
   - Accessibility score < 70 (high)

---

## Phase 5: Triage

Compile all issues found. For each issue:

```
- id: ISSUE-NNN
- severity: critical | high | medium | low
- category: functionality | form | navigation | error-handling | responsive | performance | accessibility
- page: URL where found
- description: what's broken
- repro: steps to reproduce
- evidence: screenshot filename
- fixable: true | false
```

Sort by severity. Apply tier filter:
- **Quick:** Keep critical + high only
- **Standard:** Keep critical + high + medium
- **Exhaustive:** Keep all

Mark unfixable issues (third-party widgets, infrastructure) as "deferred" regardless of tier.

Output the triage summary:
```
QA found N issues: X critical, Y high, Z medium, W low
Fixing: A issues (based on [tier] tier)
Deferred: B issues
```

---

## Phase 6: Fix Loop

For each fixable issue, in severity order:

### 6a. Locate source

Use Grep/Glob to find the source file responsible. Search for:
- Component names visible in the UI
- Error messages from console
- Route definitions matching the URL
- CSS class names from the snapshot

### 6b. Fix

- Read the source code, understand the context
- Make the **minimal fix** — smallest change that resolves the issue
- Do NOT refactor, add features, or "improve" unrelated code
- CSS-only fixes for visual issues when possible

### 6c. Commit

```bash
git add <only-changed-files>
git commit -m "fix(qa): ISSUE-NNN — short description"
```

One commit per fix. Never bundle.

### 6d. Re-verify

1. Navigate back to the affected page
2. `mcp__chrome_devtools__take_screenshot` — after screenshot
3. Read both before and after screenshots to show the user
4. `mcp__chrome_devtools__list_console_messages` — confirm no new errors
5. Repeat the interaction that triggered the bug — confirm it's fixed

### 6e. Classify

- **verified** — re-test confirms the fix, no new errors
- **best-effort** — fix applied but couldn't fully verify (needs auth, external service)
- **reverted** — regression detected → `git revert HEAD` → mark as deferred

### 6f. Self-regulation

Every 5 fixes (or after any revert), evaluate:

```
Risk score:
  Each revert:                +15%
  Each fix touching >3 files: +5%
  After fix 15:               +1% per additional fix
  Touching unrelated files:   +20%
```

**If risk > 20%:** STOP. Show the user what's been done. Ask whether to continue via `AskUserQuestion`.

**Hard cap: 30 fixes.** After 30, stop regardless of remaining issues.

---

## Phase 7: Final Verification

After all fixes:

1. Re-run a quick pass on all pages that had fixes — screenshot each
2. `mcp__chrome_devtools__list_console_messages` on each — check for new errors
3. Compare against initial baseline:
   - Any new console errors? (regression)
   - Any pages that look different than expected? (unintended side effects)

If regressions found, WARN prominently.

---

## Phase 8: Report

```markdown
# Browser QA Report
Target: [URL]
Tier: [quick | standard | exhaustive]
Date: [ISO 8601]

## Summary
- Pages tested: N
- Issues found: X critical, Y high, Z medium, W low
- Fixes applied: N (verified: A, best-effort: B, reverted: C)
- Deferred: N issues
- Console errors: before M → after N

## Issues & Fixes
### ISSUE-001 [critical] [verified]
**Page:** /checkout
**Bug:** Submit button does nothing when cart has >10 items
**Repro:** Add 11 items → click checkout → click submit → nothing happens
**Fix:** Fixed overflow check in cart-validator.js:42
**Commit:** `abc1234`
**Before:** [screenshot]
**After:** [screenshot]

### ISSUE-002 [high] [deferred]
**Page:** /settings
**Bug:** Password change form accepts empty password
**Repro:** Go to settings → clear password field → click save → succeeds
**Note:** Deferred — requires backend validation change

[... remaining issues ...]

## Performance
- Lighthouse Performance: [score]
- LCP: [value]
- CLS: [value]
- Accessibility: [score]

## Ship Readiness
[One-paragraph assessment: is this ready to ship? What must be fixed first?]

## PR Summary
> QA found N issues, fixed M. Health: [before] → [after]. [Ship-ready | Needs fixes: list]
```

---

## Execution

When invoked, immediately begin testing without asking for confirmation (unless no URL can be determined). Test like a skeptical user — click everything, try to break things, fill forms with weird data. Every bug must include reproduction steps and a screenshot. Quality over speed — 10 well-documented bugs with fixes beat 30 vague observations.
