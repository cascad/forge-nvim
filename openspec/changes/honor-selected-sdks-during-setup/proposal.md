# Proposal

## Why

IDE-BOOT-38 сохраняет Python/Node в tools.json, но явный setup/Mason продолжает
выбирать их через PATH. Выбранная среда может отличаться от среды подготовки.
Владелец также запросил E2E после цельной реализации вместо каждого изменения.

## What Changes

- Подготовить выбранные Python/Node в окружении только tools setup до Mason,
  используя существующие settings/resolvers и штатные SDK bin directories.
- Отказать до установки, если выбранный executable нельзя использовать штатным
  provider или выбранный Node не содержит npm; без wrappers/private patches.
- Добавить пакетный запуск списка файлов и явный regression: существующие
  зарегистрированные suites плюс native Python installer suites, с dry plan.
- Записать цикл: быстрые проверки при работе, один E2E batch после целого блока,
  повтор только failed/affected; большой regression на контрольной точке.

## Capabilities

### New Capabilities

- `setup-selected-sdks`: IDE-BOOT-39 — выбранная Python/Node среда tools setup.
- `test-block-workflow`: IDE-TEST-10 — проверяемые планы пакетного и полного прогона.

### Modified Capabilities

Нет IDE main specs в текущей базовой линии. Прежние SDK fallback paths и native
provider compatibility policy сохраняются; полный installer SDK picker отдельно.

## Impact

Setup entrypoints/module, test wrappers/batch plan driver, native setup E2E и
быстрые проверки плана, docs/roadmap/история. Без Docker/WSL lifecycle/SDK downloads.
