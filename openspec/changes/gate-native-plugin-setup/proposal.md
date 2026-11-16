# Proposal

## Why

IDE-138: настоящий cold Custom Core на Windows сообщил ready, хотя Git не смог checkout grug-far.nvim из-за длинного пути. Lazy удалил отсутствующий pin из installed lockfile, init печатал Too many rounds of missing plugins, но setup-stage.lua выполнял только restore/backports и возвращал0. Намерение IDE-BOOT-9/15 — отказ неполной установки — не покрывает postconditions plugins явно.

## What Changes

- Явная подготовка ставит missing plugins и восстанавливает все по исходному lock, проверяет native Lazy tasks/каталоги/HEAD; ошибка не публикует kit.
- Обычный запуск не устанавливает missing plugins. Исходный lock сохраняется и при отказе.
- Windows setup использует process-local Git core.longpaths; пользовательский Git config и SDK не меняются.
- Native offline regression для clone/build/pin failure и проверка настоящего Custom Core с обычной конфигурацией.

## Capabilities

### New Capabilities

- `plugin-setup`: IDE-BOOT-30, достоверная подготовка plugins и сохранение lock.

### Modified Capabilities

Нет; baseline phase1 не синхронизируется, IDE-BOOT-9/15 не переписываются.

## Impact

config.lazy, общий setup-stage и небольшой helper; tests/install-plugin-setup.test.py, acceptance observer, install docs/FIXLOG/history. Нет новых LSP, pins или изменений SDK/глобального Git.
