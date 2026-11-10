# Proposal

## Why

Обзор IDE-080 обнаружил пробел: Persistence проверялся только save/load в одном процессе, а config.start меняет проект через native :restart. До упрощения root/session glue нужны наблюдения настоящего выхода, нового backend и восстановления файлов.

## What Changes

- Добавить bounded native TUI baseline обычного quit/relaunch/restore и перехода между двумя проектами через существующий config.start.
- Проверить файлы, cursor/cwd, служебные панели, startup/exit PID и отсутствие ошибок; сохранить исходники и сырые артефакты.
- Подключить подтверждённые сценарии к общей E2E команде, описать результат и следующие границы обзора.

## Capabilities

### New Capabilities

Нет: test-only, skip_specs:true.

### Modified Capabilities

Production поведение не меняется. Найденный product defect требует отдельного change и source RED.

## Impact

Новые tests/e2e и test helper при необходимости, registry, обзор/журналы. Существующие 67 pins, SDK, production root/session glue прежние. Docker Desktop/WSL не управляются; Ubuntu/Mac результаты требуют реального запуска.
