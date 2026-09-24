---
max_turns: 12
timeout_seconds: 240
allowed_tools: [Skill, Read, Glob, Grep, Bash, TodoWrite]
model: sonnet
runs: 3
---
Can you review this change before I open the PR? There is no repo checked out here, the diff below is everything.

```diff
diff --git a/src/lib/paginate.ts b/src/lib/paginate.ts
index 91a0c3e..d47e2b0 100644
--- a/src/lib/paginate.ts
+++ b/src/lib/paginate.ts
@@ -1,4 +1,5 @@
 import { clamp } from "./math";
+import { Logger } from "./logger";
 
 export interface Page<T> {
   items: T[];
@@ -9,10 +10,17 @@ export interface Page<T> {
 
 export function paginate<T>(rows: T[], page: number, pageSize: number): Page<T> {
   const safeSize = clamp(pageSize, 1, 100);
-  const start = (page - 1) * safeSize;
-  const items = rows.slice(start, start + safeSize);
+  const totalPages = Math.max(1, Math.ceil(rows.length / safeSize));
+  const safePage = clamp(page, 1, totalPages);
+  const start = (safePage - 1) * safeSize;
+  const items: T[] = [];
+  for (let i = start; i <= start + safeSize && i < rows.length; i++) {
+    items.push(rows[i]);
+  }
   return {
     items,
-    page,
+    page: safePage,
     pageSize: safeSize,
     total: rows.length,
+    totalPages,
   };
 }
```
