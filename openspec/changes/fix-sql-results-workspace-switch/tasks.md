# Tasks

## 1. Исходное воспроизведение

- [x] 1.1 Добавить постоянные SQL UI cases IDE-068 для visible cached output двух SQLite workspace и пустого root; сохранить полный d43c094 config-source и ожидаемый RED по фактическим rows/header, counters исключают повторный SQL. Обновить PROBLEMS; Windows native, остальные ОС непроверены.

## 2. Выбор и отображение

- [x] 2.1 Обновлять selected output независимо от идемпотентного open; visible/hidden/empty/reverse transitions GREEN через реальные UI. Добавить lock/delayed reply case выбранного другого workspace. FIXLOG с IDE-SQL-6, причиной/изменением/E2E/выводом/файлами; HISTORY/SQL guide вместе с исправлением.

## 3. Интеграция

- [x] 3.1 Последовательно выполнить весь SQL UI, SDK CLI, common work-panel E2E, unit/trace и strict validate; проверить test/runtime/payload hashes, old FIXLOG byte prefix и штатный shutdown. Сохранить команды/evidence, обновить roadmap и коммит. Windows PASS не переносить на Ubuntu/Mac; engine не запускать.
- [ ] 3.2 Те же UI на Ubuntu с уже работающим engine, Mac на машине владельца; без среды оставить задачу открытой и предоставить команды.
