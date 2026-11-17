# Proposal

## Why

После решения владельца (§264) пути должны настраиваться без изменения fride.
Сейчас Python молча игнорирует неверный override, Node/Bash используют другие
правила, а общей настройки проекта и объяснения выбора нет.

## What Changes

- Добавить декларативные user/project tools.json с путями к Python, Node,
  native Bash, Bats, JS entrypoints Node tools и Node/Bash DAP.
- Приоритет: project, user, существующие vim.g/env, штатное обнаружение языка.
- Неверный явный путь и повреждённый config завершают выбор понятной ошибкой.
- Добавить команду отчёта в общих логах, без установки или запуска toolchains.
- Сохранить native project environment и существующие overrides.

## Capabilities

### New Capabilities

- `language-tool-paths`: IDE-BOOT-33 — общий контракт настройки путей для
  существующих Python/Node/Bash интеграций.

### Modified Capabilities

Нет изменений main specs; прежние IDE контракты находятся в незавершённых changes.

## Impact

Общий маленький модуль конфигурации и paths, существующие Python/Node/Bash/Bats
интеграции, init command, E2E, руководство и история. SDK installation, Go/Rust/SQL
consumers, политика обновлений и дополнительные DAP argv остаются следующими
срезами; существующие native launch configs по-прежнему задают аргументы.
