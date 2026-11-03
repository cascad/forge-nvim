const { test, expect } = require('@jest/globals');
const { double } = require('./src/math');
const fs = require('node:fs');

test('nearest returns 42', () => {
  const answer = double(21);
  console.log('JEST_VALUE', answer); // E2E_BREAKPOINT
  expect(answer).toBe(42);
});

test('neighbor fails', () => {
  fs.writeFileSync('neighbor-ran.txt', 'executed');
  expect(1).toBe(2);
});
