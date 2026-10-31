## 1. Реальное воспроизведение

- [x] 1.1 Подготовить pinned Go parser явно и fixture с двумя тестами.
  Проверка: загрузка parser, обычный nearest и popup red на Windows/Ubuntu.

## 2. Исправления с регрессом

- [x] 2.1 Исправить nearest/file/debug Go через закреплённый adapter.
  Проверка: IDE-TEST-1/2, путь с пробелами, соседний тест не запущен случайно.
- [x] 2.2 Ограничить eval paused-сессией, закрывать DAP float Esc/q.
  Проверка: IDE-DAP-3 без сессии и на реальном breakpoint, paused сохраняется.
- [x] 2.3 Дописать FIXLOG, docs/HISTORY, roadmap/инбокс, E2E/команды подготовки.
  Проверка: Спека IDE-TEST-1/2 и IDE-DAP-3 ADDED, ссылки и матрица сред.

## 3. Общий регресс

- [x] 3.1 Прогнать общий Windows/Ubuntu регресс после изменений.
  Проверка: nvim runner, docker full, OpenSpec strict validate, diff --check.
- [ ] 3.2 Прогнать Mac теми же командами. Проверка: владелец приложил
  результаты и версии. До этого Mac явно непроверен.
