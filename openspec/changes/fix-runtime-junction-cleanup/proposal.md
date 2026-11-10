# Proposal

## Why

IDE-094: negative Rust probes уже завершили native editor/own Job, но recursive delete не убирает dangling Content.IE5 directory junction. Scandir видит link, lstat для malformed target не работает. Fixture runtime остаётся на F: несмотря на отсутствие живого процесса.

## What Changes

- Удалять links как ссылки, не рекурсивно обходить их targets; Windows directory links поддержать через nonrecursive rmdir.
- Сохранить ownership/canonical checks, marker-last и прежний retry для настоящих file locks.
- Проверить live/dangling/malformed directory links и очистить собственные остатки negative probes.

## Capabilities

### New Capabilities

Нет, test-only `skip_specs: true`.

### Modified Capabilities

Поведение редактора/SDK не меняется.

## Impact

tests/lib/editor_runtime.lua, native filesystem E2E/fixture, история и команды. Без Windows-only изменений production IDE или управления процессами.
