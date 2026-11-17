# Proposal

## Why

Владелец уточнил базовый объём SQL/Bash: подсветка и готовые LSP/форматтеры.
Сейчас SQL язык привязан к подключению БД, patched sqls и собственной CLI
диагностике, хотя уже имеющийся upstream Sqruff поставляет штатный LSP.

## What Changes

- Обычный SQL файл использует native sqruff lsp и готовый Sqruff formatter,
  без подключения БД, sqls и собственного протокола в базовом runtime.
- Путь sqruff выбирается через общий user/project tools.json.
- Существующие операции с БД остаются явными дополнительными действиями.
  Их развитие и удаление не входят в этот срез.
- Bash сохраняет готовые bash-language-server/shfmt/ShellCheck.

## Capabilities

### New Capabilities

- `basic-sql-language`: IDE-BOOT-34 — штатная базовая поддержка SQL без БД.

### Modified Capabilities

Нет main IDE specs: они ещё находятся в changes базовой линии.

## Impact

SQL runtime/LSP/format config, общий отчёт путей, native E2E, руководства.
Упрощение installer состава SQL/Bash, готовые providers и остальные языки —
следующие срезы; текущий packager SQL parts не удаляется без обзора.
