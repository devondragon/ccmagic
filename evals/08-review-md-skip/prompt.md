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

## Skip
- `src/gen/**` generated from openapi.yaml by `make client`; never edited by hand
```

```diff
diff --git a/src/gen/petstore/client.ts b/src/gen/petstore/client.ts
index 3a1b2c4..7d8e9f0 100644
--- a/src/gen/petstore/client.ts
+++ b/src/gen/petstore/client.ts
@@ -20,5 +20,5 @@ export function listPetsUrl(base: string, page: number): string {
   const params = new URLSearchParams();
   params.set("page", String(page));
   params.set("limit", "20");
-  return `${base}/pets?${params.toString()}`;
+  return `${base}/pets${params.toString()}`;
 }
diff --git a/src/lib/greet.ts b/src/lib/greet.ts
index 1f2e3d4..5a6b7c8 100644
--- a/src/lib/greet.ts
+++ b/src/lib/greet.ts
@@ -1,4 +1,5 @@
 export function greet(name: string): string {
-  const who = name.trim().length > 0 ? name.trim() : "there";
+  const trimmed = name.trim();
+  const who = trimmed.length > 1 ? trimmed : "there";
   return `Hello, ${who}!`;
 }
```
