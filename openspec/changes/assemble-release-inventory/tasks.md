# Tasks

## 1. Единый publisher inventory

- [x] 1.1 Добавить read-only native catalog/report/notices команду с profile selection, pins/hash/receipt checks и явными gaps; tests/release-inventory.test.py проверяет CLI, strict, corrupt/drift/readonly inputs на Windows/Ubuntu.
- [x] 1.2 Сформировать отчёт реальных доступных inputs, записать точные пробелы перед Default/Custom и команды; FIXLOG §259 `Спека: IDE-BOOT-29 (ADDED)`, docs/HISTORY.md, OpenSpec strict/frozen/append-only checks и локальный коммит. Native Mac обозначить непроверенным.
