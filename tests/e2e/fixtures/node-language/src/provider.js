/** @typedef {import('./value-provider').ValueProvider} ValueProvider */
/** @implements {ValueProvider} */
class Concrete {
  readValue() { return 42; }
}
module.exports = Concrete;
