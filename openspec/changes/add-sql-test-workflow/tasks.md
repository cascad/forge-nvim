# Tasks

## 1. Native SDK

- [x] 1.1 Добавить locked Rust runner с официальным parser/validator и native SQLite, report/exit/error line и isolation; explicit preparer/readiness без compiler/scratch. Реальные process E2E Windows: pass/fail/parse/empty/Unicode/shared setup/independent runs и immutable readiness. Записать SDK commands/ограничения, FIXLOG/HISTORY (IDE-SQL-8); подготовку ОС без реального запуска не считать PASS. Самостоятельный SDK commit до UI допустим, Tests пока не объявлять готовыми.

## 2. Editor workflow

- [x] 2.1 Реализовать публичный Neotest adapter и `.slt` filetype, nearest=file script, file/all, настоящий report/output/error navigation, missing tools/DAP guard. Постоянные native editor UI E2E Windows: discovery без исполнения, source ea63bf5 RED, nearest/fail→fix→rerun/file/all/isolation/Unicode/stop/общие панели; обновить SQL guide/матрицу и FIXLOG/HISTORY (IDE-SQL-7).

- [x] 2.2 IDE-070: companion pinned Neotest backport нормализует и directory/file paths на входе discovery. Source upstream-client replay и stop→другой file/invalid→empty UI без watchdog; apply/check/revert/unknown companion process E2E. FIXLOG/HISTORY/patch guide (IDE-TEST-6), Windows PASS и явные границы остальных ОС.

## 3. Интеграция

- [x] 3.0 IDE-069: общий Run all consumer по documented Client API, actual multi-adapter/foreign-workspace UI и source RED empty-adapter; записать FIXLOG/HISTORY (IDE-TEST-5), общий Tests guide и результаты Windows. Непроверенные ОС остаются открытыми.

- [x] 3.1 Добавить SDK/UI suites в общий runner/Ubuntu recipe; последовательно Windows SQL query/SDK/common panels и затронутые language Tests, unit/trace/strict OpenSpec. Проверить sources/payload/pins/history prefix/shutdown, записать evidence/команды/roadmap и коммит. IDE-062 references оставить открытым.
- [ ] 3.2 Те же native SDK/UI на Ubuntu при уже доступном engine и Mac владельца. Реальных запусков нет — оставить задачу открытой; Docker/WSL lifecycle не менять. Проверка: одинаковые команды SQL guide плюс platform artifacts.

Windows интеграция 3.1 завершена после постоянного IDE-075 lifecycle fix:
111 native checks PASS, 2 POSIX SKIP, 365 unit/trace и 64 strict valid;
история §136. Ubuntu/Mac задача 3.2 остаётся открытой, references IDE-062 отдельно.
