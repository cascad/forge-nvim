# Tasks

## 1. Базовый SQL runtime

- [x] 1.1 Подключить штатный Sqruff LSP/formatter и общий path resolver, прежнюю DB setup выполнять явно. Проверка: sql-basic E2E с настоящим binary, lint/format и без DB startup, Windows/Ubuntu.
- [x] 1.2 Сохранить explicit advanced fixture и добавить basic E2E в registry собственной delta. Проверка: старый SQL query smoke Windows/Ubuntu и новый standalone SQL без БД; no startup install.
- [x] 1.3 Записать выбранную базу SQL/Bash и остаток installer/audit, FIXLOG `Спека: IDE-BOOT-34 (ADDED)`, docs/HISTORY/commands. Проверка: OpenSpec strict, frozen/prefix/index guards, локальный commit.
