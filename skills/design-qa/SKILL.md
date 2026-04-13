---
description: Design quality audit — catches AI slop, scores visual polish, fixes issues with atomic commits
allowed-tools: Read(*), Edit(*), Write(*), Bash(git:*), Glob(*), Grep(*), Agent(*), AskUserQuestion(*), mcp__chrome_devtools__navigate_page(*), mcp__chrome_devtools__take_screenshot(*), mcp__chrome_devtools__evaluate_script(*), mcp__chrome_devtools__resize_page(*), mcp__chrome_devtools__take_snapshot(*), mcp__chrome_devtools__lighthouse_audit(*), mcp__chrome_devtools__list_console_messages(*)
argument-hint: "[URL] [--quick|--deep|--diff]"
model: sonnet
context: fork
---

# Design QA

Post-build design quality gate. Navigates your live site, detects AI slop patterns, audits visual polish across 7 categories, scores the design, and fixes issues with atomic commits.

> **Browser required:** This skill uses Chrome DevTools MCP to screenshot, inspect, and interact with your site. If Chrome DevTools MCP is unavailable, it falls back to source-code-only analysis (reduced coverage).

## Step 0: Parse Arguments & Detect Target

Parse `$ARGUMENTS` to determine mode and target URL:

| Argument | Mode | Description |
|----------|------|-------------|
| *(empty)* | auto | Detect running dev server, or ask for URL |
| `<URL>` | url | Audit the given URL |
| `--quick` | quick | Homepage + 2 key pages only |
| `--deep` | deep | 8-10 pages, full checklist |
| `--diff` | diff | Scope to pages changed by current branch |

**Auto-detect dev server** if no URL given:

```bash
for port in 3000 4000 5173 8080 8000; do curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -q "200\|301\|302" && echo "FOUND: http://localhost:$port" && break; done
```

If no server found and no URL given, use `AskUserQuestion` to ask for a URL.

**Diff mode:** When `--diff` is specified or auto-detected (on a feature branch):
1. Run `git diff main...HEAD --name-only` to find changed files
2. Map changed files to affected routes/pages
3. Audit only those pages

**Check Chrome DevTools MCP availability:**

Try `mcp__chrome_devtools__navigate_page` with the target URL. If the tool is unavailable or errors, set `BROWSER_AVAILABLE=false` and note: "Chrome DevTools MCP unavailable — running source-code-only audit (reduced coverage). Steps 1-3 will use code analysis instead of live inspection."

**Check for clean working tree** (needed for fix loop):

```bash
git status --porcelain
```

If dirty, use `AskUserQuestion`:
- A) Commit my changes first, then start design QA
- B) Continue without fix loop (audit-only, no commits)

---

## Step 1: Page Classification & First Impression

**Navigate** to the target URL using `mcp__chrome_devtools__navigate_page`.

**Screenshot** the full page using `mcp__chrome_devtools__take_screenshot`.

**Read the screenshot** with the Read tool so it's visible in the conversation.

**Classify the page** as one of:
- **MARKETING/LANDING** — hero-driven, brand-forward, conversion-focused
- **APP UI** — workspace-driven, data-dense, task-focused
- **HYBRID** — marketing shell with app-like sections

This classification determines which checklist rules apply throughout the audit.

**First Impression** — form a gut reaction before any analysis:
- "The site communicates **[what]**."
- "I notice **[observation]**."
- "The first 3 things my eye goes to: **[1]**, **[2]**, **[3]**."
- "One-word verdict: **[word]**."

Be opinionated. A designer reacts, they don't hedge.

**Source-code fallback:** If no browser, classify by reading the main HTML/JSX entry point and examining the component structure.

---

## Step 2: Design System Extraction

Use `mcp__chrome_devtools__evaluate_script` to extract the actual rendered design system:

**Fonts:**
```js
JSON.stringify([...new Set([...document.querySelectorAll('*')].slice(0,500).map(e => getComputedStyle(e).fontFamily))])
```

**Colors:**
```js
JSON.stringify([...new Set([...document.querySelectorAll('*')].slice(0,500).flatMap(e => [getComputedStyle(e).color, getComputedStyle(e).backgroundColor]).filter(c => c !== 'rgba(0, 0, 0, 0)'))])
```

**Heading hierarchy:**
```js
JSON.stringify([...document.querySelectorAll('h1,h2,h3,h4,h5,h6')].map(h => ({tag:h.tagName, text:h.textContent.trim().slice(0,50), size:getComputedStyle(h).fontSize, weight:getComputedStyle(h).fontWeight})))
```

**Touch targets (undersized interactive elements):**
```js
JSON.stringify([...document.querySelectorAll('a,button,input,[role=button]')].filter(e => {const r=e.getBoundingClientRect(); return r.width>0 && (r.width<44||r.height<44)}).map(e => ({tag:e.tagName, text:(e.textContent||'').trim().slice(0,30), w:Math.round(e.getBoundingClientRect().width), h:Math.round(e.getBoundingClientRect().height)})).slice(0,20))
```

**Border-radius values:**
```js
JSON.stringify([...new Set([...document.querySelectorAll('[class*=card],button,input,div')].slice(0,200).map(el => getComputedStyle(el).borderRadius).filter(r => r !== '0px'))])
```

Structure findings as an **Inferred Design System**:
- **Fonts:** list with count. Flag if >3 distinct families.
- **Colors:** palette extracted. Flag if >12 unique non-gray colors.
- **Heading Scale:** h1-h6 sizes. Flag skipped levels or non-systematic jumps.
- **Border-Radius:** list unique values. Flag if only 1 value used across all elements.
- **Touch Targets:** list undersized elements.

**Source-code fallback:** Grep CSS/SCSS/Tailwind files for font-family, color values, border-radius patterns.

---

## Step 3: AI Slop Detection

Load `${CLAUDE_SKILL_DIR}/slop-patterns.md`.

For each of the 10 anti-patterns:

1. **Visual check** — Analyze the screenshot(s) taken in Step 1 for the visual signature
2. **JS check** — Run the pattern's JS snippet via `mcp__chrome_devtools__evaluate_script`
3. **Classify** — DETECTED or CLEAN

Output a pattern-by-pattern report:

```
## AI Slop Detection

| # | Pattern | Result | Evidence |
|---|---------|--------|----------|
| 1 | Purple gradients | CLEAN | — |
| 2 | 3-column feature grid | DETECTED | Found on homepage, 3 cards with icon-circles |
| 3 | Icons in colored circles | DETECTED | 6 instances found |
| ... | ... | ... | ... |

**AI Slop Score: C** (2 patterns detected — looks AI-assisted)
```

**Source-code fallback:** Grep for gradient definitions, flex/grid with exactly 3 children, border-radius: 50% patterns, text-align: center prevalence.

---

## Step 4: Checklist Audit

Load `${CLAUDE_SKILL_DIR}/checklist.md`.

### Page scope
- **Quick mode:** Homepage + 2 key pages (navigation targets)
- **Default mode:** 5-6 pages reachable from homepage
- **Deep mode:** 8-10 pages including all navigation targets and key user flows

### For each page in scope:

1. **Navigate** using `mcp__chrome_devtools__navigate_page`
2. **Screenshot** desktop (1440px) using `mcp__chrome_devtools__take_screenshot`
3. **Check console errors** using `mcp__chrome_devtools__list_console_messages`
4. **Apply checklist** — evaluate each item against the rendered page

### Responsive testing

For each page, resize and screenshot at three breakpoints:

1. `mcp__chrome_devtools__resize_page` to width 375 (mobile) — screenshot
2. `mcp__chrome_devtools__resize_page` to width 768 (tablet) — screenshot
3. `mcp__chrome_devtools__resize_page` to width 1440 (desktop) — restore

Read each screenshot with the Read tool so they're visible in conversation.

### Performance check

Run `mcp__chrome_devtools__lighthouse_audit` on the homepage for Performance category. Extract LCP, CLS, and overall performance score.

### Finding format

For each issue found:

```
[CATEGORY] (impact: high|medium|polish) description
  Location: page URL, element/area
  Suggested fix: specific CSS or structural change
```

---

## Step 5: Scoring

### AI Slop Score (from Step 3)

| Detected | Grade |
|----------|-------|
| 0 | A |
| 1 | B |
| 2-3 | C |
| 4-5 | D |
| 6+ | F |

### Design Score (from Step 4)

Per-category grades computed per the checklist scoring rules:
- Start at A
- Each high-impact finding: drop one letter
- Each medium-impact finding: drop half a letter
- Polish findings: noted, no grade impact

Weighted average across categories + AI Slop (5% weight) = **Design Score**.

Output:

```
## Scores

Design Score: [A-F]
AI Slop Score: [A-F]

| Category | Grade | Findings |
|----------|-------|----------|
| Visual Hierarchy | B | 1 high, 0 medium |
| Typography | A | 0 findings |
| ... | ... | ... |
```

---

## Step 6: Triage & Fix Loop

Sort all findings by impact (high first, then medium).

### Auto-fixable findings

Findings that are mechanical CSS changes (wrong value, missing property, straightforward addition):
- Fix directly in source code
- Prefer CSS-only changes (safest, most reversible)
- One commit per fix: `git add <files> && git commit -m "style(design): FINDING-NNN — description"`
- After each fix, navigate back and re-screenshot to verify

Output per fix:
```
[AUTO-FIXED] FINDING-003 — Body text 14px → 16px (typography)
  Changed: src/styles/global.css:42
  Committed: style(design): FINDING-003 — increase body text to 16px
```

### Judgment-call findings

Findings that require design decisions or structural changes — present via `AskUserQuestion` in a single batch:

```
I auto-fixed N issues. M need your input:

1. [HIGH] FINDING-001 — 3-column feature grid detected on homepage
   Fix: Restructure to asymmetric layout (e.g., large feature left, two small right)
   → A) Fix  B) Skip

2. [MEDIUM] FINDING-005 — All headings centered, no left-aligned text
   Fix: Left-align section headings, keep hero centered
   → A) Fix  B) Skip

RECOMMENDATION: Fix both — #1 is the strongest AI slop signal, #2 improves hierarchy.
```

Apply fixes for items where the user chose "Fix."

### Self-regulation

After every 5 fixes:
- Navigate to the homepage and screenshot
- Compare against the first impression screenshot
- Check for regressions (did fixes break the overall look?)
- If regression detected: `git revert HEAD` and mark finding as "deferred"

---

## Step 7: Report

Output a structured report:

```markdown
# Design QA Report
Target: [URL]
Classification: [MARKETING | APP UI | HYBRID]
Date: [ISO 8601]

## Scores
Design Score: [A-F]
AI Slop Score: [A-F]

## First Impression
[gut reaction from Step 1]

## Inferred Design System
[extracted fonts, colors, spacing from Step 2]

## AI Slop Detection
[pattern-by-pattern table from Step 3]

## Findings by Category
### Visual Hierarchy ([grade])
[findings]

### Typography ([grade])
[findings]

[... remaining categories ...]

## Fixes Applied ([count])
[list of commits with what changed]

## Quick Wins
[top 3-5 highest-impact unfixed items with specific instructions]
```

The **Quick Wins** section is the most actionable output for someone who isn't a designer — the 3-5 changes that would most improve the site, with exact instructions.

---

## Execution

When invoked, immediately begin the workflow without asking for confirmation (unless no URL can be determined). Be opinionated about design quality — this skill exists to catch problems a non-designer would miss. Every finding should include a specific, actionable fix, not just an observation.
