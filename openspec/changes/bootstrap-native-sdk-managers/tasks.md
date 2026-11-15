# Tasks

## 1. Явный bootstrap

- [x] 1.1 Добавить штатный discovery менеджера вне PATH и bootstrap WinGet/Homebrew с отдельным confirmation; проверить Windows native PTY и Linux missing-APT flow.
- [x] 1.2 Сохранить отдельное SDK confirmation, retry/cancel/headless guarantees и Mac SDK discovery; проверить controlled native fixture E2E, native Mac отметить непроверенным.

## 2. Регресс и история

- [x] 2.1 Прогнать одну целевую SDK iteration Windows и Ubuntu, сохранить исходные ошибки/trace и удалить только собственные тяжёлые временные payloads. Команды: tests/install-sdk-bootstrap.test.py и tests/install-sdk-actions.test.py.
- [x] 2.2 Обновить install plan/SDK guide, FIXLOG с IDE-BOOT-21, HISTORY и команды; проверить append-only journals, frozen SDK/lock/WIP и strict OpenSpec validate; локальный коммит по точному allowlist.
