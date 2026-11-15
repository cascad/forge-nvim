# Proposal

## Why

Владелец уточнил границу изоляции: fride владеет редактором, библиотеками и IDE-инструментами; Go/Rust/Node/npm/Python остаются штатными SDK пользователя. Коммит 6387a4b / IDE-BOOT-16 нарушил это намерение: достаточно запустить установленный fride с заданным GOPATH/RUSTUP_HOME/npm prefix, чтобы scripts/install-private.lua и launch-managed.* подменили эти значения.

## What Changes

- Удалить общую SDK policy, переназначение SDK homes/config/cache/prefix и дополнительные SDK bin paths.
- Сохранить приватные Neovim/config/plugins/Mason/state/logs/temp и существующее окружение SDK/проекта.
- Сохранить старые sdk-state файлы при обновлении, больше не использовать их автоматически.
- Отменить начатую упаковку Node как части IDE. Для недостающих SDK планировать предложение установки с выбором пользователя, а не автоматическую установку; изучить VS Code и IntelliJ IDEA.
- Заменить регресс прежней ошибочной policy проверкой повторного использования native SDK.

## Capabilities

### New Capabilities

- `native-sdk-reuse`: граница приватного IDE и пользовательских SDK при setup и запуске.

### Modified Capabilities

Нет: IDE-BOOT-16 существует в незавершённой baseline change, не в main specs. Новый контракт IDE-BOOT-17 явно заменяет его решение.

## Impact

scripts/install-private.lua, launch-managed.*, tests/install-sdk-state.test.py, SDK_STATE и текущий installation roadmap. Полная доставка IDE-инструментов и UX установки недостающих SDK остаются следующими явно отслеживаемыми этапами IDE-138.
