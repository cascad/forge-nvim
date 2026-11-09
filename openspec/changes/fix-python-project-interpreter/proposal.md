# Proposal

## Why

IDE-052: на runtime 6988af1 Python DAP/pytest находят .venv, но Pyright не
получает выбранный interpreter и не видит установленную только в проекте
dependency. Реальный UI RED — 11098768461700 и повтор Python v2; server settings
не содержат pythonPath, gd в dependency заканчивается No locations found.

## What Changes

- Вынести существующий выбор Python DAP в общий portable resolver, сохранив
  его приоритеты и системную границу Scripts/bin.
- До инициализации Pyright передавать project interpreter через pythonPath;
  сохранять явно заданный Python path и не запускать DAP ради LSP.
- Постоянный Python workflow E2E из verify-python-language-workflow: dependency
  definition, semantic completion/diagnostics, format/save, DAP и pytest.
- История/команды/матрица с source RED/GREEN, Windows регресс и честные ОС.

## Capabilities

### New Capabilities

- python-interpreter: IDE-PY-1 — согласованное разрешение project Python для LSP/DAP.

### Modified Capabilities

Нет соответствующей базовой Python capability; baseline specs содержат только
WezTerm/install. Новая delta описывает намерение после доказанного сбоя.

## Impact

Новый общий resolver, plugins/lsp.lua и существующий DAP caller. Без новых
plugins/SDK или установки tools на startup. Neotest сохраняет свой native
resolver (включая managers), положительный plain venv проверяется тем же E2E.
