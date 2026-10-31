## 1. Воспроизведение

- [x] 1.1 Добавить fixture Go со stdout/stderr, breakpoint и panic; реальный
  editor E2E с F5/F9, повтором и скрытием панелей. Проверка: Windows red,
  snapshots, события и версии настоящего Go/Delve; адаптер не подменяется.
- [x] 1.2 Подготовить Go/Delve в Ubuntu Docker явно при build.
  Проверка: запуск того же E2E без сети с подтверждёнными версиями.

## 2. Исправление

- [x] 2.1 Закрепить единую очистку при новом запуске, сохранять вывод новой
  сессии и восстанавливать отсутствующую область на паузе.
  Проверка: IDE-DAP-1 на Windows/Ubuntu, предыдущий stdout/stderr не теряется.
- [x] 2.2 Добавить доступные exceptionInfo/description в Output на паузе,
  исключить устаревшие ответы. Проверка: IDE-DAP-2 на реальном panic;
  session остаётся paused, реальный stderr после continue сохраняется.

- [x] 2.3 Дописать FIXLOG (Спека: IDE-DAP-1/2 ADDED), docs/HISTORY,
  roadmap/инбокс/матрицу E2E и команды подготовки. Проверка: ссылки и результаты.

## 3. Общий регресс

- [x] 3.1 Прогнать ядро/editor/DAP и имеющийся регресс Windows/Ubuntu.
  Проверка: scripts/test.*, docker full, OpenSpec strict validate, diff --check.
- [ ] 3.2 Прогнать Mac. Проверка: владелец запускает тот же suite с Go/Delve,
  прикладывает .tests и версии. До этого Mac явно непроверен.
