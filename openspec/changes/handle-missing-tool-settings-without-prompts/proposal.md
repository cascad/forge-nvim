# Proposal

## Why

Большой checkpoint §275 подтвердил: неверный explicit путь выбрасывает ошибку
из LSP/Run/Debug callbacks. Пользователь получает hit-enter вместо доступного
редактора и контекстного сообщения в Logs. Следующий блок roadmap — исправить это.

## What Changes

- Обработать ошибки строгих resolvers на границах runtime consumers Node/Bash,
  общего LSP guard и связанных Run/Debug команд, сохранив source/reason.
- Не запускать другую копию из PATH при invalid override, не создавать задачу/
  DAP session и не устанавливать SDK. После исправления настройки разрешить retry.
- Добавить native editor regressions и усилить прежние missing/recovery checks;
  один affected batch на ОС после целого исправления, затем failed-only retries.

## Capabilities

### New Capabilities

- `nonblocking-tool-errors`: IDE-BOOT-41 — ошибки настроек tools без блокировки редактора.

### Modified Capabilities

IDE main specs ещё не опубликованы; строгий контракт IDE-BOOT-33 и preflight
IDE-BOOT-40 сохраняется. Меняется обработка ошибок у runtime consumers.

## Impact

Общие tool-path guards, Node/Bash LSP/Run/Debug, native E2E и история.
Без новых LSP/providers, private API, SDK installation или изменения lockfiles.
