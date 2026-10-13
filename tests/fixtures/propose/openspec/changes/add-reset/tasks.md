## 1. Reset a counter

- [ ] 1.1 Add `reset(counter)` to `src/counter.js`, setting `counter.value` to 0 and returning 0, and export it
- [ ] 1.2 Add tests in `test/counter.test.js` for a reset below the cap and a reset at the cap, each asserting the value is 0 afterward

## 2. Report a capped increment

- [ ] 2.1 Change `increment` in `src/counter.js` to return `{ value, capped }`, with `capped` true only when the counter was already at the cap
- [ ] 2.2 Update the increment tests in `test/counter.test.js` to assert both fields below the cap and at the cap
