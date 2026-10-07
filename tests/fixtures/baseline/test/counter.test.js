const test = require('node:test');
const assert = require('node:assert');
const { createCounter, increment } = require('../src/counter');

test('increments by one', () => {
  assert.strictEqual(increment(createCounter()), 1);
});

test('stops at the cap', () => {
  assert.strictEqual(increment(createCounter(100)), 100);
});
