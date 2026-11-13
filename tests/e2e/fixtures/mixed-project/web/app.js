const fs = require('node:fs');
fs.writeFileSync('node-run.txt', process.cwd() + '|' + process.argv[2]);
console.log('MIX_NODE_SCRIPT', process.argv[2]);
