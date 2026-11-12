# Tasks

## 1. Общая подготовка запуска

- [x] 1.1 Добавить permanent dap-launch-routes E2E/registry: actual CodeLLDB,
  source fd6b965 Windows PASS для F5/default, Space dP single/multiple/cancel,
  source buffer/args и трёх fresh PTY. Подтвердить исходный PASS до refactor.
- [x] 1.2 Свести одинаковые последовательности в plugins/dap.lua без нового
  module; target launch-routes и существующие Go/Python/Node/Rust debug E2E
  Windows, same order/reset/cancel, root exit/scopes и unit/trace/strict.
- [x] 1.3 Записать FIXLOG/HISTORY/commands и актуальную очередь; append-only
  guard, git diff --check; зафиксировать Windows evidence и открытые платформы.

## 2. Платформенная проверка

- [ ] 2.1 Пройти source/target и выбранный debug regression Ubuntu при доступном
  engine, проверить source identity/root/API/scopes; native Mac не засчитывать.
- [ ] 2.2 Повторить native проверки на Mac и записать actual результат.
