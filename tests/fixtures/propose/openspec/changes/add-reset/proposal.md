# Proposal

## Why

A counter that reaches the cap of 100 stays there for good, so a reader who wants to count a second batch has to create a new counter and lose the old reference. A reset lets the same counter start over.

## What Changes

- Add a reset operation that sets a counter back to 0.
- An increment on a counter at the cap now says so in its return value instead of returning the cap silently.

## Capabilities

### New Capabilities
- `resetting`: setting a counter back to its starting value.

### Modified Capabilities
- `counting`: the Increment requirement reports when the cap stopped an increment.

## Impact

- `src/counter.js`: a new `reset` export and a changed `increment` return value.
- Callers of `increment` that compare its result with the cap.

## Coverage

Source: docs/brief.md (the counter reset brief).

| Requirement | Covered by |
|---|---|
| R1. A counter can be set back to zero | Section 1 |
| R2. An increment at the cap is visible to the caller | Section 2 |
| R3. A reset is logged | Not covered: no logging exists in this code; see the final report |
