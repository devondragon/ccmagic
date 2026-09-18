---
max_turns: 8
timeout_seconds: 180
allowed_tools: [Skill, Read]
model: sonnet
runs: 3
---
Write a Jest test for this function. Cover the empty-input case and a normal case.

```ts
export function sumPositive(values: number[]): number {
  return values.filter((v) => v > 0).reduce((acc, v) => acc + v, 0);
}
```
