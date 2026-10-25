---
type: llm
focus: last_message
---
In src/lib/greet.ts the condition changed from `length > 0` to `trimmed.length > 1`, so a one-character name such as "A" is now greeted as "there".

Score 1 if the review flags the `> 1` condition and says that one-character names are no longer used (or equivalent). Score 0 otherwise.
