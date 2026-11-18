# Proposal

## Why

После §285 actual Default/Custom archive/Core workflow прошли Windows/Ubuntu.
Нужно проверить существующие language consumers внутри установленного Default,
а не подменять это source-config E2E. Это проверка существующего поведения,
новых требований/SDK managers нет; skip_specs=true.

## What Changes

- Диагностический native observer: managed config/runtime, реальные LSP,
  диагностика и исправление/форматирование шести языков в owned sample project.
- Документировать actual platform evidence и оставшиеся Mac/WSL/cold SDK gates.

## Impact

Test-only helper/docs/история. При найденном product bug отдельный change,
без неявного изменения поведения в verification change.
