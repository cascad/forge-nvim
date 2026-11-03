# Proposal

## Why

IDE-050: Go файл без golines/gofumpt не форматируется через доступный gopls.
Реальный E2E 1473803432600 остаётся без изменений и без formatting request.
Причина в plugins/format.lua: common trim попадает в список Conform и считается
полноценным formatter, блокируя намеренный LSP fallback.

## What Changes

- Общая очистка не блокирует LSP, когда языковые внешние formatter недоступны.
- Сохраняются внешнее форматирование и common trim без LSP/formatter.
- Реальные Go formatting/сохранение E2E, исходный RED и совместимость cleanup;
  companion verify-go-language-workflow готовит инструменты и общий harness.

## Capabilities

### New Capabilities

- `editor-formatting`: IDE-FMT-1, языковое форматирование и fallback.

### Modified Capabilities

Нет: main spec форматирования пока отсутствует.

## Impact

Общий Conform config, tests/e2e/go-language.test.lua, docs/FIXLOG/HISTORY.
Без нового plugin/backport/SDK и платформенных runtime веток. Другие языки
не объявляются проверенными по Go E2E; Ubuntu/Mac только после реального запуска.
