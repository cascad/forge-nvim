# Design

## Context

Владельцем выбран базовый объём SQL/Bash. Sqruff уже входит в существующий
catalog, поставляет sqruff lsp и форматтер. Закреплённый nvim-lspconfig уже
содержит sqruff config. Собственный SQLs protocol нужен только старым DB actions.

## Goals / Non-Goals

**Goals:** стандартный LSP без БД, общий путь Sqruff, сохранение project rules,
native E2E на Windows/Ubuntu.

**Non-Goals:** новые LSP, патчи upstream, новые SQL runners/DB adapters, развитие
Bash DAP. Удаление прежних возможностей и изменение installer parts — после
обзора состава. Bash остаётся на имеющихся bash-language-server/shfmt/ShellCheck.

## Decisions

- Маленькая sql_language интеграция применяет native vim.lsp.config/enable
  и Conform. Команда upstream: sqruff lsp, никакого CLI-to-LSP translation.
- Путь из общего resolver; native lookup/Mason сохраняется как fallback.
  SQL dialect/rules берутся из .sqruff; default CLI dialect остаётся ansi.
- Старый sql.setup_lsp запускает только basic setup; прежняя DB setup вынесена
  в явный setup_connections перед SQLRun/SQLConnect. CLI diagnostics wrapper
  подключается только там, не к обычным SQL файлам.
- Отчёт путей показывает Sqruff без version/probe. E2E использует реальный
  подготовленный binary, .sqruff и обычный SQL файл без DB settings.

## Risks / Trade-offs

- Sqruff предоставляет lint/format, не DB schema intelligence → базовый объём
  явно описан; DB actions остаются отдельной прежней возможностью.
- Поведение parse diagnostics зависит от upstream → проверяем настоящие lint
  diagnostics/format, не пишем новый обход LSP. Не обещаем старый SQLs completion.
- Старые SQL E2E предполагали DB LSP сразу → их DB fixture явно включает прежнюю
  интеграцию; отдельная basic fixture проверяет отсутствие DB startup.
