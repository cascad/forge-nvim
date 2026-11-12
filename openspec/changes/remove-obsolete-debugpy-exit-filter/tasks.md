# Tasks

## 1. Диагностика debugpy

- [x] 1.1 Добавить permanent actual-debugpy E2E и подтвердить Windows source
  RED: CLI exit2/stderr сохранён, notification отсутствует; mocks не применять.
- [x] 1.2 Удалить legacy debugpy suppression, проверить Windows target UI/Logs/
  editor recovery и Python normal/pytest shutdown, Go control, unit/trace/strict.
- [x] 1.3 Записать IDE-111/IDE-DAP-6 в FIXLOG/HISTORY/commands и roadmap;
  проверить append-only guard и git diff --check, отразить непроверенные ОС.

## 2. Платформы

- [ ] 2.1 Повторить source/target и выбранный regression на Ubuntu при доступном
  engine; проверить actual source/root/API/scopes, не засчитывать старый Windows.
- [ ] 2.2 Пройти actual Mac и physical delivery отдельно, сохранить результаты.
