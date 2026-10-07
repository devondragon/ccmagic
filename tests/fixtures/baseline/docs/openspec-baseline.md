# OpenSpec baseline evidence

Repository: tally (a ccmagic test fixture). Baseline commit: 0000000000000000000000000000000000000000. Written 2026-10-06 by /ccmagic:spec-baseline, OpenSpec CLI 1.13.2.

## 1. Capability map

| Capability | Observable purpose | Implementing files | Tests | Status |
|---|---|---|---|---|
| counting | A counter capped at 100 and the text that shows a count | `src/counter.js`, `src/format.js` | `test/counter.test.js` | specified, 3 requirements |

### Not specified

- The module exports: wiring, not behavior.

## 2. counting

Path key: `Counter` is `src/counter.js`.

### Requirement: Counter start
- Scenario: No start value. Code: `Counter:4-6`. Tests: UNTESTED.
- Scenario: Start value above the cap. Code: `Counter:2`, `:5`. Tests: `test/counter.test.js::stops at the cap`.

### Requirement: Increment
- Scenario: Below the cap. Code: `Counter:8-14`. Tests: `test/counter.test.js::increments by one`.
- Scenario: At the cap. Code: `Counter:9-11`. Tests: `test/counter.test.js::stops at the cap`.
- Open question: whether a counter created above the cap and then incremented should stay at the cap.

### Requirement: Count display
- Scenario: Single item. Code: `src/format.js:3-5`. Tests: UNTESTED.
- Scenario: Any other count. Code: `src/format.js:6`. Tests: UNTESTED.

### Left out of the spec on purpose
- The comment headers in both modules.
