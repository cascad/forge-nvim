# Proposal

## Why

Очередь4/WF-08–09: merge/rebase resolve/abort проверены, native interactive
sequence editor ещё нет. Сначала проверяем готовый Neogit без нового Git UI.
Windows source1 PASS/1 FAIL: submit работает, abort1972523353100 сохраняет
HEAD/tree/refs/clean state, но выдаёт ложный conflict ERROR. IDE-123/IDE-GIT-13:
native rebase_interactive проверяет только stdout[1] и ожидает hint+error одной
строкой, тогда как Git выдаёт две. Upstream default blobed8aa001577a31ada0ae76e8342d6db0e314bfd8 содержит тот же дефект.

## What Changes

- Native E2E на disposable local Git repo: reorder/fixup/submit, abort и настоящий interactive conflict с последующим native abort.
- Управление native todo editor клавиатурой, реальный Git graph/tree после.
- Windows/Ubuntu по одному прогону, history/docs и явные native platform gates.
- Узкий проверяемый patch закреплённого Neogit: распознавать editor-abort при отдельных строках hint/error; genuine conflict остаётся ERROR.

## Capabilities

### New Capabilities

- `git-sequence-editor`: IDE-GIT-13, корректный результат отмены todo editor.

### Modified Capabilities

Прежние Git требования остаются; source failure получил отдельный regression.

## Impact

E2E/registry/docs/history и ещё один файл существующего Neogit patch manifest.
6 patched dependencies/14 files вместо13; pins/Neovim SDK прежние, новый Git backend не добавляется.
Никакой production history/push/credentials; Mac/physical отдельно.
