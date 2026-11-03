# Design

## Context

Причина — proposal.md. RED 1685513867400: публичный list_formatters_to_run
возвращает trim_whitespace/trim_newlines и lsp=false, хотя подходящий LSP client
есть. Простое удаление trim ломает очистку файлов без языковых инструментов.

## Goals / Non-Goals

**Goals:** корректный fallback всех общих форматирующих entrypoints, сохранить
common trim и выбор внешнего formatter, включая проверку метода самим Conform.
**Non-Goals:** backport Conform, новые серверы/SDK, отдельный Go workaround,
снятие guards auto-save или изменение поведения других языков без проверки.

## Decisions

1. Декларативный список formatter становится публичной filetype-функцией:
   get_formatter_info проверяет реальные availability; если хоть один внешний
   formatter доступен, сохраняется fallback, иначе lsp_format=first. Conform
   сам проверяет наличие клиента для текущего document/range метода и выполняет
   LSP перед общей очисткой. Без клиента выполняются прежние trim formatter.
2. Unknown filetype получает ту же политику через _. Common * trim сохраняется.
   Не копируем внутренний resolver и не отключаем capabilities клиента.
3. Manual/shortcut/Format/format_after_save не затирают выбранную filetype
   политику безусловным fallback. Health учитывает динамический список и first.
4. Шесть реальных UI E2E companion change покрывают server семантику, внешний
   формат, три маршрута LSP fallback и common trim без LSP/formatter.
   Артефакт содержит source, LspRequest observer и точный formatter plan.

## Risks / Trade-offs

- Dynamic configuration → health должен корректно показать first/fallback.
- Cleanup потеряется → отдельный Go/plaintext сценарий без LSP и внешних tools.
- Один entrypoint переопределит политику → проверка Space lf, Format, Shift+Alt+f.
- Ubuntu engine отсутствует → оставляем проверку открытой, не запускаем Desktop.
