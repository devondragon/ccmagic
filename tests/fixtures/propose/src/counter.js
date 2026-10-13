// A counter that stops at a fixed cap.
const MAX = 100;

function createCounter(start = 0) {
  return { value: Math.min(start, MAX) };
}

function increment(counter) {
  if (counter.value >= MAX) {
    return counter.value;
  }
  counter.value += 1;
  return counter.value;
}

module.exports = { MAX, createCounter, increment };
