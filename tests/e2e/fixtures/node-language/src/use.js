const { double } = require('./math');

function use() {
  return double(21);
}

function otherUse() {
  return double(2);
}

module.exports = { use, otherUse };
