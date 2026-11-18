# Proposal

## Why

IDE-011 требует metadata/gate, не позволяющий объявить IDE change готовым
без E2E. Сейчас trace знает ADDED ID, но не проверяет их строки Проверка;
наличие unit или отсутствующего файла может остаться без ошибки. SQL
references остаются желаемой незавершённой возможностью, не исключением PASS.

## What Changes

- Сохранить ADDED/MODIFIED metadata в existing spec_index и проверять
  declared paths активных IDE requirements через existing trace.
- Каталог IDE: registered E2E presence отдельно от native PASS. Незавершённое
  требование без E2E — PENDING; завершённый change/основная IDE спека без E2E — FAIL.
- Учесть существующий standalone Python inventory установщика через общий
  batch_plan discovery; native CLI cases вынести из unit, не дублировать запуск.
- Добавить trace --change для строгой проверки до завершения change и JSON
  каталога в отчёт, не вводя вторую систему деклараций.
- Исправить отсутствующие/неразобранные ссылки у Peek/native sorter/late
  focus/frame pilot; диагностический helper не выдавать за registered E2E.
- Permanent native CLI source/target E2E: invalid/valid/pending/archive,
  completed/selected/main/MODIFIED и unknown change.

## Capabilities

### New Capabilities

Нет; skip_specs=true, тестовая инфраструктура и metadata, поведение IDE прежнее.

### Modified Capabilities

Нет; в existing delta specs уточняются только ссылки на имеющиеся проверки.

## Impact

spec_index/trace/trace CLI/run report, native E2E/registry, test docs и история.
Без нового test framework, service management, LSP/backend/SDK/pins изменений.
SQL references остаются PENDING; обязательные native OS gates не закрываются.
