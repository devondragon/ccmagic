---
max_turns: 12
timeout_seconds: 240
allowed_tools: [Skill, Read, Glob, Grep, TodoWrite]
model: sonnet
runs: 3
---
/ccmagic:review

There is no git repository or checkout in this directory. The diff below is the complete change on my branch; review it as-is.

```diff
diff --git a/src/utils/format.ts b/src/utils/format.ts
index 3f1c2a9..8b7d4e1 100644
--- a/src/utils/format.ts
+++ b/src/utils/format.ts
@@ -12,14 +12,14 @@ export function formatCurrency(amount: number, currency: string): string {
   return formatter.format(amount);
 }
 
-// Formats a duration in ms as a human string
+// Formats a duration in milliseconds as a human-readable string, e.g. "1h 04m 09s".
 export function formatDuration(ms: number): string {
   const totalSeconds = Math.floor(ms / 1000);
   const hours = Math.floor(totalSeconds / 3600);
   const minutes = Math.floor((totalSeconds % 3600) / 60);
   const seconds = totalSeconds % 60;
   if (hours > 0) {
-    logger.debug("format dur " + ms);
+    logger.debug(`formatDuration: ${ms}ms -> ${hours}h ${minutes}m ${seconds}s`);
     return `${hours}h ${pad(minutes)}m ${pad(seconds)}s`;
   }
   return `${pad(minutes)}m ${pad(seconds)}s`;
```
