const { double } = require('./src/math');
const prettier = require('prettier');
const fs = require('node:fs');
console.log('NODE_BEFORE', process.argv[2] || 'default');
process.stderr.write('NODE_STDERR\n');
const answer = double(21);
console.log('NODE_VALUE', answer); // E2E_BREAKPOINT
console.log('LOCAL_PRETTIER', prettier.version);
fs.writeFileSync('run-cwd.txt', process.cwd());
