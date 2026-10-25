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

## Nit cap
2
```

```diff
diff --git a/src/lib/labels.ts b/src/lib/labels.ts
new file mode 100644
index 0000000..b1c2d3e
--- /dev/null
+++ b/src/lib/labels.ts
@@ -0,0 +1,21 @@
+export function joinLabels(labels: string[]): string {
+  var out = "";
+  for (var i = 0; i < labels.length; i++) {
+    if (i > 0) {
+      out = out + ", ";
+    }
+    out = out + labels[i];
+  }
+  return out;
+}
+
+export function truncateLabel(label: string): string {
+  if (label.length > 24) {
+    return label.substring(0, 21) + "...";
+  }
+  return label;
+}
+
+export function isBlank(s: string): boolean {
+  return s.trim().length == 0 ? true : false;
+}
```
