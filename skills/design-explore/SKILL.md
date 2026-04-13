---
description: Generate multiple distinct design directions, compare in browser, pick a winner before building
allowed-tools: Read(*), Write(*), Edit(*), Bash(git:*, curl:*), Glob(*), Grep(*), Agent(*), AskUserQuestion(*), mcp__chrome_devtools__navigate_page(*), mcp__chrome_devtools__take_screenshot(*), mcp__chrome_devtools__evaluate_script(*), mcp__chrome_devtools__resize_page(*)
argument-hint: "[page/component description] [--count N] [--evolve URL]"
model: sonnet
context: fork
---

# Design Explore

Generate 3-6 meaningfully different design directions as full HTML/CSS pages, open them in the browser for visual comparison, and iterate until you pick a winner. This runs *before* building — it's visual brainstorming, not review.

> **Why this matters:** Without this, Claude generates one design and you accept it. That first attempt is almost always generic. Forcing multiple distinct directions surfaces better options.

## Step 0: Parse Arguments

| Argument | Description |
|----------|-------------|
| *(empty)* | Ask what to design |
| `<description>` | Design brief (e.g., "landing page for my SaaS", "settings dashboard") |
| `--count N` | Number of variants (default 3, max 6) |
| `--evolve URL` | Screenshot the existing page and generate improvement variants |

## Step 1: Context Gathering

### Auto-gather (before asking questions)

1. Check for `DESIGN.md` or `design-system.md` — if found, read it. All variants must respect this as the baseline design system.
2. Check existing frontend code:
   ```bash
   ls src/ app/ pages/ components/ public/ 2>/dev/null | head -30
   ```
3. Check for a running dev server:
   ```bash
   for port in 3000 4000 5173 8080 8000; do curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -q "200\|301\|302" && echo "FOUND: http://localhost:$port" && break; done
   ```

### Evolve mode

If `--evolve URL` is given or a dev server is running and the user said something like "I don't like how this looks":
1. Navigate to the URL using `mcp__chrome_devtools__navigate_page`
2. Take a screenshot with `mcp__chrome_devtools__take_screenshot`
3. Read the screenshot to show the user what we're starting from
4. Extract the current design system (fonts, colors, layout) via `mcp__chrome_devtools__evaluate_script`
5. Use this as the basis — variants are *improvements*, not blank-slate alternatives

### Context questions

Pre-fill what you inferred, then ask ONE question covering gaps. Use `AskUserQuestion`:

> "Here's what I know: [pre-filled context from codebase/DESIGN.md].
>
> I need to know:
> - Who is this for? (audience/persona)
> - What's the one thing users should do on this page? (primary action)
> - Any specific aesthetic direction? (dark/light, minimal/bold, specific brands you like)
> - How many variants? (default 3)
>
> A) Answer above
> B) Just explore — surprise me with 3 directions"

If user picks B, make reasonable assumptions and note them. Two rounds max of questions, then proceed.

## Step 2: Concept Generation

Generate N distinct design concepts. Each must be a genuinely different creative direction, not a color swap.

**Distinctness rules:**
- Each variant must differ in at least 2 of: layout structure, color scheme, typography approach, visual density, interaction pattern
- Name each concept with a short evocative name
- One sentence describing the visual direction

Present concepts for confirmation:

```
I'll explore 3 directions:

A) "Minimal Mono" — monochrome palette, generous whitespace, single accent color, large type
B) "Dense Dashboard" — dark theme, compact layout, data-forward, subtle gradients
C) "Bold Editorial" — strong typography hierarchy, asymmetric grid, vivid photography areas
```

Use `AskUserQuestion`:
- A) Generate all — looks good
- B) Change some (tell me which)
- C) Add more variants
- D) Drop some

One round of revision, then proceed.

## Step 3: Generate HTML Variants

### Output setup

```bash
VARIANT_DIR="/tmp/design-explore-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$VARIANT_DIR"
```

### Parallel generation

Launch N Agent subagents in a single message, one per variant. Each agent generates a complete, self-contained HTML file.

**Agent prompt template** (one per variant):

```
Generate a complete, self-contained HTML file for a design variant.

Design brief: {full brief with concept direction}
Concept: {concept name and description}
Design system constraints: {from DESIGN.md or inferred system}
Evolve from: {screenshot analysis if evolve mode, otherwise "fresh design"}

Requirements:
1. Single HTML file with inline CSS and minimal inline JS if needed
2. Must be fully self-contained — no external dependencies except Google Fonts CDN
3. Must be responsive (works at 375px, 768px, 1440px)
4. Use real-looking placeholder content, not lorem ipsum
5. The design must feel DISTINCT from the other variants — not a color swap
6. Apply the AI Slop avoidance rules:
   - No purple/indigo gradients
   - No 3-column icon-in-circle feature grids
   - No centered-everything layout
   - No uniform bubbly border-radius
   - No generic hero copy ("Welcome to X", "Unlock the power of...")
   - No decorative blobs or wavy dividers
   - No emoji as design elements
7. Write production-quality CSS — systematic spacing, type scale, color variables
8. Include a subtle "Variant {letter}: {concept name}" label fixed to the bottom-right

Save to: {VARIANT_DIR}/variant-{letter}.html

After saving, verify the file exists and report its size.
```

### Results

After all agents complete:
1. List which variants succeeded/failed
2. For any failures, report the error and offer to retry

## Step 4: Visual Comparison

Open each variant in the browser for the user to see:

For each variant file:
1. `mcp__chrome_devtools__navigate_page` to `file://{VARIANT_DIR}/variant-{letter}.html`
2. `mcp__chrome_devtools__resize_page` to width 1440 (desktop)
3. `mcp__chrome_devtools__take_screenshot` — save and Read to show inline
4. `mcp__chrome_devtools__resize_page` to width 375 (mobile)
5. `mcp__chrome_devtools__take_screenshot` — save and Read to show inline

After showing all variants (desktop + mobile for each), use `AskUserQuestion`:

```
Here are the {N} variants, each shown at desktop and mobile:

A) {concept name} — [your 1-line reaction to what you generated]
B) {concept name} — [reaction]
C) {concept name} — [reaction]

Options:
1) Pick a winner (tell me which letter)
2) Pick a winner with changes ("A, but with B's color scheme")
3) Remix — combine elements ("A's layout + C's typography")
4) None of these — regenerate with new direction
5) More variants — add N more directions
```

## Step 5: Iterate (if needed)

If the user picks option 2, 3, 4, or 5:

**Option 2 (winner with changes):** Take the winner HTML, apply the requested changes, regenerate, show updated version. One round.

**Option 3 (remix):** Generate a new variant combining specified elements from multiple variants. Show result, ask for approval.

**Option 4 (regenerate):** Ask what was wrong with all options, generate new concepts, go back to Step 2.

**Option 5 (more variants):** Generate additional concepts that are distinct from the existing ones, generate HTML, show alongside originals.

Cap at 3 rounds of iteration. After 3 rounds, recommend picking the closest option and refining during build.

## Step 6: Save Approved Direction

Once the user picks a winner:

1. Copy the approved HTML to the project:
   ```bash
   mkdir -p .design-refs
   cp "{VARIANT_DIR}/variant-{letter}.html" ".design-refs/{screen-name}-approved.html"
   ```

2. Extract design decisions into a brief:
   ```
   ## Approved Design Direction: {concept name}

   - Layout: {description}
   - Colors: {extracted palette}
   - Typography: {fonts and scale}
   - Key patterns: {notable design choices}
   - User feedback: {what the user said about it}
   ```

3. Use `AskUserQuestion` for next steps:
   > "Design direction saved to `.design-refs/{name}-approved.html`. What's next?"
   > - A) Build it — start implementing this design in the actual codebase
   > - B) Save and continue — I'll reference this later
   > - C) Run /design-qa after building — queue up a quality check

**Source-code fallback:** If Chrome DevTools MCP is unavailable, skip the visual comparison screenshots. Instead, save the HTML files and tell the user: "I've generated {N} variants at {paths}. Open them in your browser to compare, then tell me which you prefer."

## Execution

When invoked, immediately begin context gathering. Be opinionated about design quality — every variant should be something a professional designer would consider shipping. The AI Slop avoidance rules are non-negotiable for all variants.
