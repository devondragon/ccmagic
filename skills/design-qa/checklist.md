# Design Audit Checklist

42 items across 7 categories. Apply per-page against the live rendered site.

Each finding gets: **category**, **impact** (high/medium/polish), **description**, **suggested fix**.

---

## 1. Visual Hierarchy & Composition (6 items)

- [ ] **Clear focal point** — One primary CTA or content piece per view. Multiple competing elements = visual noise.
- [ ] **Natural eye flow** — Eye moves naturally from top-left through content. No orphaned elements pulling attention sideways.
- [ ] **Information density** — Appropriate for content type. Data-dense apps can be dense; marketing pages need breathing room.
- [ ] **Above-the-fold clarity** — Purpose of the page is clear within 3 seconds of landing.
- [ ] **Squint test** — Blur your eyes: hierarchy should still be visible. If everything blends together, hierarchy is too flat.
- [ ] **Intentional white space** — Space is used deliberately to group and separate. Not just leftover gaps.

### Page-type modifiers
- **MARKETING:** First viewport reads as one composition, not a dashboard. Brand > headline > body > CTA hierarchy.
- **APP UI:** Primary workspace dominates. Navigation is subordinate. One accent color maximum.

---

## 2. Typography (8 items)

- [ ] **Font count <= 3** — Flag if more than 3 distinct font families are in use.
- [ ] **Type scale follows ratio** — Sizes should follow a ratio (1.25 major third or 1.333 perfect fourth), not arbitrary values.
- [ ] **Line-height** — Body text: 1.5x. Headings: 1.15-1.25x. Tighter headings, looser body.
- [ ] **Measure (line length)** — 45-75 characters per line (66 ideal). Flag text blocks wider than 75ch.
- [ ] **Heading hierarchy** — No skipped levels (h1 -> h3 without h2). Levels used semantically, not for styling.
- [ ] **Weight contrast** — At least 2 font weights used to create hierarchy (e.g., 400 body, 700 headings).
- [ ] **Body text >= 16px** — Anything smaller is hard to read on most screens.
- [ ] **Generic font flag** — If the primary font is Inter, Roboto, Open Sans, or Poppins, flag as potentially generic. Not a failure, but a signal.

---

## 3. Color & Contrast (6 items)

- [ ] **Palette coherence** — 12 or fewer unique non-gray colors. More than 12 = no color system.
- [ ] **WCAG AA contrast** — Body text: 4.5:1 ratio. Large text (18px+): 3:1. UI components: 3:1.
- [ ] **Semantic color consistency** — Success = green, error = red, warning = amber. Used consistently across all pages.
- [ ] **No color-only encoding** — Information conveyed by color must also have labels, icons, or patterns. (8% of men have red-green deficiency.)
- [ ] **Dark mode coherence** — If dark mode exists: surfaces use elevation (not just inverted lightness), text is off-white (~#E0E0E0 not pure white), accent colors are slightly desaturated.
- [ ] **Neutral palette consistency** — Warm grays or cool grays, not mixed. Mixed neutrals feel unintentional.

---

## 4. Spacing & Layout (8 items)

- [ ] **Grid consistency** — Layout follows a consistent grid at all breakpoints. Elements snap to the same column structure.
- [ ] **Spacing scale** — Spacing uses a systematic scale (4px or 8px base). Flag arbitrary values like 13px, 17px, 23px.
- [ ] **Alignment** — All elements on a page align to a shared edge or grid. Nothing floats outside the system.
- [ ] **Proximity rhythm** — Related items are closer together. Distinct sections are further apart. The spacing tells you what groups with what.
- [ ] **Border-radius hierarchy** — Radius varies by element type (small for inputs, medium for cards, large for modals). Not one value for everything.
- [ ] **No horizontal scroll** — At any viewport width. Ever.
- [ ] **Max content width** — Body text and content have a max-width. No full-bleed paragraphs at 2560px.
- [ ] **Responsive breakpoints** — Tested at: 375px (mobile), 768px (tablet), 1024px (desktop), 1440px (wide).

---

## 5. Interaction States (5 items)

- [ ] **Hover state** — All interactive elements (buttons, links, cards) have a visible hover state.
- [ ] **Focus-visible ring** — Keyboard focus indicator is present. Never `outline: none` without a replacement. Check for `focus-visible` usage.
- [ ] **Disabled state** — Disabled elements have reduced opacity + `cursor: not-allowed`. Clearly non-interactive.
- [ ] **Loading states** — Skeleton shapes match real content layout. Shimmer animation if applicable. Not just a spinner.
- [ ] **Empty states** — "No items" screens have a warm message + primary action + visual. Not just "No results found."

---

## 6. Responsive Design (5 items)

- [ ] **Mobile layout is designed, not stacked** — Mobile should make design sense, not just be desktop columns collapsed vertically.
- [ ] **Touch targets >= 44px** — All tappable elements are at least 44x44px on mobile viewports.
- [ ] **No horizontal scroll on mobile** — Test at 375px width specifically.
- [ ] **Navigation collapses** — Desktop nav converts to hamburger, bottom nav, or appropriate mobile pattern.
- [ ] **No zoom restriction** — No `user-scalable=no` or `maximum-scale=1` in viewport meta tag.

---

## 7. Performance as Design (4 items)

- [ ] **LCP < 2.0s** — Largest Contentful Paint under 2 seconds for web apps, under 1.5s for informational sites.
- [ ] **CLS < 0.1** — No visible layout shifts during page load. Content doesn't jump.
- [ ] **Image optimization** — Images use `loading="lazy"`, have width/height attributes set, and use modern formats (WebP/AVIF).
- [ ] **Font loading** — `font-display: swap` used. Critical fonts preloaded. No visible flash of unstyled text (FOUT).

---

## Scoring

Per-category grades:

| Grade | Meaning |
|-------|---------|
| A | Intentional, polished, shows design thinking |
| B | Solid fundamentals, minor inconsistencies |
| C | Functional but generic. No major problems, no point of view |
| D | Noticeable problems. Feels unfinished |
| F | Actively hurting user experience |

**Grade computation:** Start at A. Each high-impact finding drops one letter grade. Each medium-impact finding drops half a letter grade. Polish findings are noted but don't affect the grade. Minimum is F.

**Design Score** is a weighted average:

| Category | Weight |
|----------|--------|
| Visual Hierarchy | 20% |
| Typography | 15% |
| Color & Contrast | 15% |
| Spacing & Layout | 20% |
| Interaction States | 10% |
| Responsive Design | 10% |
| Performance as Design | 5% |
| AI Slop (from slop-patterns.md) | 5% |
