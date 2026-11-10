# Proposal

## Why

Следующий пункт IDE-080/PANEL_OWNERSHIP_REVIEW — сравнить поиск окна кода до рефакторинга. По source функции не эквивалентны: state может создать split, activities принимает больше типов окон, panel_guard исключает markers/Edgy и выбирает цель для переноса. Сначала нужны native факты, иначе общий helper незаметно изменит фокус/restore.

## What Changes

- Bounded diagnostic `tests/diagnostics/code-window.lua`: настоящий editor, обычные windows, native float/terminal, marked file и Persistence restore из native session с winfix.
- Таблица источников, условий и side effects, наблюдения Windows/Ubuntu, рекомендации и оставшиеся gates в `docs/CODE_WINDOW_REVIEW.md`.
- Append-only FIXLOG/HISTORY/AGENT_COMMANDS и актуальный следующий шаг roadmap.

## Capabilities

### New Capabilities

Нет: диагностический инструментарий и обзор, skip_specs=true.

### Modified Capabilities

Нет. Поведение редактора не меняется, спорные наблюдения не утверждаются как новый контракт.

## Impact

tests/diagnostics и docs. Production Lua, SDK, pins и main specs остаются прежними. Результаты macOS требуют отдельного запуска владельцем. Docker используется только при уже доступном engine, без управления Desktop/WSL.
