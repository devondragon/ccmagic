---
max_turns: 16
timeout_seconds: 300
allowed_tools: [Skill, Read, Glob, Grep, Bash, TodoWrite]
model: sonnet
runs: 3
---
/ccmagic:review

There is no git repository or checkout in this directory. The diff below is the complete change on my branch, and the repository's REVIEW.md (from main) is pasted above it; review the diff as-is.

```markdown
# REVIEW.md

## Failure modes
- Docs: it lies. A doc comment or README line that describes behavior the code does not have is High.
```

```diff
diff --git a/src/http/fetch-json.ts b/src/http/fetch-json.ts
index 4c5d6e7..8f9a0b1 100644
--- a/src/http/fetch-json.ts
+++ b/src/http/fetch-json.ts
@@ -1,9 +1,9 @@
 /**
  * Fetch a URL and parse the body as JSON.
- * Defaults to 30 seconds and retries twice.
+ * Defaults to 30 seconds and retries three times.
  */
 export async function fetchJson<T>(url: string, opts: { timeoutMs?: number; retries?: number } = {}): Promise<T> {
-  const timeoutMs = opts.timeoutMs ?? 30_000;
-  const retries = opts.retries ?? 2;
+  const timeoutMs = opts.timeoutMs ?? 10_000;
+  const retries = opts.retries ?? 3;
   return withRetries(retries, () => getJson<T>(url, timeoutMs));
 }
```
