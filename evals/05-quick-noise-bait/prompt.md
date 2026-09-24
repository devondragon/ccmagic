---
max_turns: 12
timeout_seconds: 240
allowed_tools: [Skill, Read, Glob, Grep, Bash, TodoWrite]
model: sonnet
runs: 3
---
/ccmagic:review

There is no git checkout in this directory. Review the diff below as the complete branch change.

```diff
diff --git a/src/lib/slug.ts b/src/lib/slug.ts
index 1a2b3c4..5d6e7f8 100644
--- a/src/lib/slug.ts
+++ b/src/lib/slug.ts
@@ -1,20 +1,20 @@
-import { normalize } from "./unicode";
 import { MAX_SLUG_LENGTH } from "../config";
+import { normalize } from "./unicode";
 
-/**
- * Convert an arbitrary title into a URL-safe slug.
- * Lowercases, strips diacritics, collapses runs of non-alphanumerics to "-".
- */
 export function slugify(title: string): string {
-  const base = normalize(title).toLowerCase();
-  const collapsed = base.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
-  return collapsed.slice(0, MAX_SLUG_LENGTH);
+  const base  = normalize(title).toLowerCase();
+  const collapsed = base.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
+  // TODO: consider a transliteration table for CJK titles
+  return collapsed.slice(0,MAX_SLUG_LENGTH);
 }
 
 export function isValidSlug(slug: string): boolean {
   return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug) && slug.length <= MAX_SLUG_LENGTH;
 }
diff --git a/src/lib/slug.test.ts b/src/lib/slug.test.ts
index 9f8e7d6..0a1b2c3 100644
--- a/src/lib/slug.test.ts
+++ b/src/lib/slug.test.ts
@@ -1,6 +1,6 @@
-import { describe, expect, it } from "vitest";
 import { isValidSlug, slugify } from "./slug";
+import { describe, expect, it } from "vitest";
 
 describe("slugify", () => {
   it("lowercases and hyphenates", () => {
@@ -12,6 +12,10 @@ describe("slugify", () => {
     expect(slugify("Crème Brûlée")).toBe("creme-brulee");
   });
 
+  it("trims leading and trailing hyphens", () => {
+    expect(slugify("--hello world--")).toBe("hello-world");
+  });
+
   it("caps length", () => {
     expect(slugify("a".repeat(500)).length).toBeLessThanOrEqual(80);
   });
```
