# Proposal

## Why

Владелец принял native SDK environment как основу (§270), но общего выбора
установленных Go/Rust SDK и ручного пути в редакторе нет. SDK должен быть
одинаковым для LSP/run/debug/tests без правки private API адаптеров.

## What Changes

- Добавить ForgeSdk: текущая среда/версия/источник, асинхронный список реально
  установленных SDK, ручной executable/root, refresh и отмена.
- Сохранять user/project выбор и явное «Авто», с project priority и ошибкой
  неверного пути без скрытого fallback.
- Применять выбор через native окружение процесса fride, с явным restart и
  восстановлением проекта; не прерывать активные debug/tests/tasks/terminal.
- Не менять глобальные PATH/profiles/SDK homes и installations. Без настройки
  сохранять исходное окружение; discovery не скачивает отсутствующие SDK.
- Добавить native Windows/Ubuntu E2E, Mac — отдельный прогон владельца.

## Capabilities

### New Capabilities

- `native-sdk-selection`: IDE-BOOT-37 — выбор существующих Go/Rust сред проекта.

### Modified Capabilities

Нет main specs для IDE в текущей базовой линии; session restore переиспользуется.

## Impact

Early SDK environment/settings и native UI, config.start restart integration,
настоящие SDK/TUI E2E, руководство/план/история. SDK providers/installation,
Python/Node UI и новые адаптеры не входят; существующие workflows сохраняются.
