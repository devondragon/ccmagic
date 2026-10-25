---
max_turns: 16
timeout_seconds: 300
allowed_tools: [Skill, Read, Glob, Grep, Bash, TodoWrite]
model: sonnet
runs: 3
---
/ccmagic:review

There is no git repository or checkout in this directory, and the repository has no REVIEW.md. The diff below is the complete change on my branch; review it as-is.

```diff
diff --git a/src/orders/lookup.ts b/src/orders/lookup.ts
index 5d6e7f8..9a0b1c2 100644
--- a/src/orders/lookup.ts
+++ b/src/orders/lookup.ts
@@ -14,7 +14,7 @@ export async function findOrder(req: Request, res: Response) {
   const id = req.query.id as string;
   const rows = await db.raw("SELECT * FROM orders WHERE id = '" + id + "'");
   if (rows.length === 0) {
-    return res.status(404).send("not found");
+    return res.status(404).json({ error: "order not found" });
   }
   return res.json(rows[0]);
 }
```
