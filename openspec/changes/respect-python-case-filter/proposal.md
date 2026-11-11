# Proposal

## Why

IDE-096: общий e2e --id IDE-PANEL-15 запускал три посторонних Python SELF wrappers. Python_case обходит check.matches и ищет/запускает Python независимо от FORGE_TEST_ID, хотя остальные Lua cases фильтруются до работы.

## What Changes

- Использовать существующее общее правило фильтра до поиска Python; чужой ID даёт пустой успешный файл без subprocess.
- Сохранить прежний ok/FAIL/SKIP, exit codes, UTF8 argv и stdout/stderr выбранного Python suite.
- Native CLI E2E с настоящими Neovim/Python и файловым признаком выполнения; source RED, полный и targeted runner regression.

## Capabilities

### New Capabilities

Нет: test harness, skip_specs:true.

### Modified Capabilities

Production nvim_forge/WezTerm поведение и main specs не меняются.

## Impact

tests/lib/python_case.lua, native E2E/fixtures/registry, README/roadmap/история. Без нового runner, дополнительных dependencies, product modules, SDK/pins и Docker/WSL управления.
