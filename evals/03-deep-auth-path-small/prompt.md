---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Skill, Read, Glob, Grep, Agent, Task, TodoWrite]
model: sonnet
runs: 3
---
/ccmagic:review

No git repository is checked out here. The diff below is the entire change on the branch; review it directly.

```diff
diff --git a/src/auth/session.ts b/src/auth/session.ts
index 5c2e7a1..9e0f3b2 100644
--- a/src/auth/session.ts
+++ b/src/auth/session.ts
@@ -21,17 +21,12 @@ export async function validateSession(token: string): Promise<Session | null> {
   const record = await sessionStore.get(token);
   if (!record) {
     return null;
   }
-  if (record.expiresAt <= Date.now()) {
-    await sessionStore.delete(token);
-    metrics.increment("session.expired");
-    return null;
-  }
   if (record.revoked) {
     return null;
   }
-  return { userId: record.userId, roles: record.roles, expiresAt: record.expiresAt };
+  return { userId: record.userId, roles: record.roles };
 }
```
