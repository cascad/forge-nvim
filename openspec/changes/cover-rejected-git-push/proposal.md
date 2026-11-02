# Proposal

## Why

Этап 5 покрывает успешный commit/push, но отказ Git ещё не проверен сквозным
сценарием. Нужны видимая причина, сохранность commit/remote и возможность
исправить состояние и повторить push из редактора.

## What Changes

- Проверить настоящий rejected push после независимого remote commit,
  отказ от предложенного force и чтение причины через историю команд.
- Проверить недоступный локальный remote, сохранность локального commit
  и успешный повтор после исправления URL.
- Выполнить Windows/Ubuntu E2E, записать историю, команды и границы покрытия.
- Исправлять runtime только при воспроизведённом нарушении сценария;
  использовать существующий Neogit/Git без отдельного Git backend.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-10, ошибки push и повтор. Основного Git spec ещё
  нет; capability продолжает unarchived `integrate-git-workflow` и IDE-GIT-1…9.

### Modified Capabilities

Нет.

## Impact

Новые real editor E2E, registry, документация и история. Только частные
локальные bare remotes, identity и config fixtures; внешний сервер и
credentials не нужны. Изоляция ConPTY IDE-039, merge/rebase-конфликты и
Mac/GUI остаются отдельными шагами.
