---
max_turns: 40
timeout_seconds: 900
allowed_tools: [Skill, Read, Glob, Grep, Bash, Agent, Task, TodoWrite]
model: sonnet
runs: 3
---
Can you code review this? It adds a user search endpoint. There is no repository checked out here, so work from the diff below; it is the complete change.

```diff
diff --git a/src/api/routes.ts b/src/api/routes.ts
index 2b1f0aa..7c3d9e4 100644
--- a/src/api/routes.ts
+++ b/src/api/routes.ts
@@ -3,6 +3,7 @@ import { Router } from "express";
 import { requireAuth } from "../auth/middleware";
 import { getUser } from "./users/get";
 import { updateUser } from "./users/update";
+import { searchUsers } from "./users/search";
 
 export const api = Router();
 
@@ -10,3 +11,4 @@ api.use(requireAuth);
 
 api.get("/users/:id", getUser);
 api.patch("/users/:id", updateUser);
+api.get("/users", searchUsers);
diff --git a/src/api/users/search.ts b/src/api/users/search.ts
new file mode 100644
index 0000000..a91c4d2
--- /dev/null
+++ b/src/api/users/search.ts
@@ -0,0 +1,68 @@
+import type { Request, Response } from "express";
+import { db } from "../../db";
+import { toPublicUser, type PublicUser } from "./serialize";
+
+const DEFAULT_LIMIT = 25;
+const MAX_LIMIT = 100;
+
+interface SearchQuery {
+  q?: string;
+  role?: string;
+  limit?: string;
+  offset?: string;
+  sort?: string;
+}
+
+const SORTABLE = new Set(["created_at", "email", "display_name"]);
+
+function parseLimit(raw: string | undefined): number {
+  const n = Number.parseInt(raw ?? "", 10);
+  if (Number.isNaN(n) || n <= 0) return DEFAULT_LIMIT;
+  return Math.min(n, MAX_LIMIT);
+}
+
+function parseOffset(raw: string | undefined): number {
+  const n = Number.parseInt(raw ?? "", 10);
+  if (Number.isNaN(n) || n < 0) return 0;
+  return n;
+}
+
+export async function searchUsers(req: Request<unknown, unknown, unknown, SearchQuery>, res: Response) {
+  const { q, role, sort } = req.query;
+  const limit = parseLimit(req.query.limit);
+  const offset = parseOffset(req.query.offset);
+
+  const clauses: string[] = ["deleted_at IS NULL"];
+  if (q && q.trim().length > 0) {
+    const term = q.trim();
+    clauses.push("(email ILIKE '%" + term + "%' OR display_name ILIKE '%" + term + "%')");
+  }
+  if (role) {
+    clauses.push("role = '" + role + "'");
+  }
+
+  const orderBy = sort && SORTABLE.has(sort) ? sort : "created_at";
+
+  const sql =
+    "SELECT id, email, display_name, role, created_at FROM users WHERE " +
+    clauses.join(" AND ") +
+    " ORDER BY " + orderBy + " DESC" +
+    " LIMIT " + limit + " OFFSET " + offset;
+
+  try {
+    const rows = await db.query(sql);
+    const users: PublicUser[] = rows.map(toPublicUser);
+    res.json({ users, limit, offset });
+  } catch (err) {
+    req.log?.error({ err }, "user search failed");
+    res.status(500).json({ error: "search failed" });
+  }
+}
+
+export const __test = { parseLimit, parseOffset };
diff --git a/src/api/users/search.test.ts b/src/api/users/search.test.ts
new file mode 100644
index 0000000..c0ffee1
--- /dev/null
+++ b/src/api/users/search.test.ts
@@ -0,0 +1,47 @@
+import { describe, expect, it, vi, beforeEach } from "vitest";
+import { searchUsers, __test } from "./search";
+
+vi.mock("../../db", () => ({ db: { query: vi.fn() } }));
+import { db } from "../../db";
+
+function mockRes() {
+  const res: any = {};
+  res.status = vi.fn().mockReturnValue(res);
+  res.json = vi.fn().mockReturnValue(res);
+  return res;
+}
+
+describe("parseLimit", () => {
+  it("defaults when missing or invalid", () => {
+    expect(__test.parseLimit(undefined)).toBe(25);
+    expect(__test.parseLimit("abc")).toBe(25);
+    expect(__test.parseLimit("-5")).toBe(25);
+  });
+  it("caps at the max", () => {
+    expect(__test.parseLimit("500")).toBe(100);
+  });
+});
+
+describe("parseOffset", () => {
+  it("defaults to zero", () => {
+    expect(__test.parseOffset(undefined)).toBe(0);
+    expect(__test.parseOffset("-1")).toBe(0);
+  });
+});
+
+describe("searchUsers", () => {
+  beforeEach(() => {
+    (db.query as any).mockReset();
+  });
+
+  it("returns matching users", async () => {
+    (db.query as any).mockResolvedValue([
+      { id: 1, email: "a@example.com", display_name: "A", role: "member", created_at: "2026-01-01" },
+    ]);
+    const res = mockRes();
+    await searchUsers({ query: { q: "a" } } as any, res);
+    expect(res.json).toHaveBeenCalledWith(
+      expect.objectContaining({ users: expect.any(Array), limit: 25, offset: 0 })
+    );
+  });
+});
```
