# AI Slop Detection Patterns

10 anti-patterns that mark a frontend as AI-generated. Each pattern includes what to look for visually (screenshot analysis) and what to check programmatically (JS extraction via `mcp__chrome_devtools__evaluate_script`).

The test: would a human designer at a respected studio ever ship this?

---

## 1. Purple/Violet/Indigo Gradients

**Visual:** Background gradients using purple, violet, or indigo tones. Blue-to-purple color schemes.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('*')].slice(0,300).map(e => getComputedStyle(e).backgroundImage).filter(bg => bg !== 'none' && /purple|violet|indigo|#[5-9a-f]{2}[0-4]{2}[a-f]{2}/i.test(bg)).length)
```
**Why it's slop:** Every AI model defaults to purple gradients. It's the "I didn't specify a color" tell.

## 2. The 3-Column Feature Grid

**Visual:** Three cards side-by-side, each with: icon in a colored circle + bold title + 2-line description. Symmetrically arranged. THE most recognizable AI layout.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('[class*=grid],[class*=flex]')].filter(el => {const kids = [...el.children]; return kids.length === 3 && kids.every(k => k.querySelector('svg,img,[class*=icon]') && k.querySelector('h2,h3,h4,strong'))}).length)
```
**Why it's slop:** Real products have asymmetric feature presentations. Three identical cards is a template, not a design.

## 3. Icons in Colored Circles

**Visual:** SVG or icon font icons placed inside colored circular backgrounds as section decoration.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('div,span')].filter(el => {const s = getComputedStyle(el); return s.borderRadius === '50%' && s.backgroundColor !== 'rgba(0, 0, 0, 0)' && s.backgroundColor !== 'rgb(255, 255, 255)' && el.querySelector('svg,[class*=icon]')}).length)
```
**Why it's slop:** The SaaS starter template look. Real designers use icons without wrapping them in decorative circles.

## 4. Centered Everything

**Visual:** All headings, descriptions, and cards centered on the page. No left-aligned text blocks.
**JS check:**
```js
JSON.stringify({centered: [...document.querySelectorAll('h1,h2,h3,p')].filter(el => getComputedStyle(el).textAlign === 'center').length, total: document.querySelectorAll('h1,h2,h3,p').length})
```
**Why it's slop:** If >70% of text elements are centered, the layout lacks intentional hierarchy. Real designs mix alignments.

## 5. Uniform Bubbly Border-Radius

**Visual:** Every element (cards, buttons, inputs, images) has the same large border-radius (12px+).
**JS check:**
```js
JSON.stringify([...new Set([...document.querySelectorAll('.card,[class*=card],button,input,[class*=rounded]')].slice(0,100).map(el => getComputedStyle(el).borderRadius))])
```
**Why it's slop:** Real design systems have a border-radius hierarchy (small for inputs, medium for cards, large for modals). Uniform radius = no design system.

## 6. Decorative Blobs and Wavy Dividers

**Visual:** Floating circles, gradient blobs, wavy SVG section dividers, or abstract background shapes used as decoration.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('svg')].filter(svg => {const html = svg.outerHTML.toLowerCase(); return /circle.*circle|ellipse|blob|wave|curve/i.test(html) && svg.getBoundingClientRect().width > 100}).length)
```
**Why it's slop:** If a section feels empty, it needs better content, not decoration. Blobs are the AI equivalent of clip art.

## 7. Emoji as Design Elements

**Visual:** Rocket emojis in headings, emoji as bullet points, emoji in card titles.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('h1,h2,h3,h4,li,td')].filter(el => /[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/u.test(el.textContent)).length)
```
**Why it's slop:** Emoji in UI chrome signals "generated, not designed." Professional interfaces use purpose-built icons.

## 8. Colored Left-Border on Cards

**Visual:** Cards with a colored left border (3-4px solid accent color) as the primary visual distinction.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('[class*=card],div')].filter(el => {const s = getComputedStyle(el); return s.borderLeftWidth !== '0px' && s.borderLeftStyle === 'solid' && s.borderLeftColor !== s.borderTopColor}).length)
```
**Why it's slop:** A lazy way to add "visual interest" to a flat card. Real designs use elevation, spacing, or typography for hierarchy.

## 9. Generic Hero Copy

**Visual:** Headlines like "Welcome to [X]", "Unlock the power of...", "Your all-in-one solution for...", "Transform your workflow with...".
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('h1,h2,[class*=hero] *')].filter(el => /welcome to|unlock the|all-in-one|transform your|supercharge|revolutionize|streamline your|empower your|elevate your/i.test(el.textContent)).map(el => el.textContent.trim().slice(0,60)))
```
**Why it's slop:** Generic copy means generic thinking. Real products have specific value propositions.

## 10. Cookie-Cutter Section Rhythm

**Visual:** Hero -> 3 features -> testimonials -> pricing -> CTA. Every section the same height. No variation in density or pacing.
**JS check:**
```js
JSON.stringify([...document.querySelectorAll('section,[class*=section]')].map(el => ({tag: el.className.slice(0,30), h: Math.round(el.getBoundingClientRect().height)})))
```
**Why it's slop:** Real pages have varied section heights reflecting content importance. Uniform rhythm = template, not design.

---

## Scoring

Count detected patterns and grade:

| Detected | Grade | Verdict |
|----------|-------|---------|
| 0 | A | Clean — no AI tells detected |
| 1 | B | Minor — one pattern, likely coincidental |
| 2-3 | C | Noticeable — looks AI-assisted |
| 4-5 | D | Obvious — reads as AI-generated |
| 6+ | F | Template — needs significant design rethinking |
