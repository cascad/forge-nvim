# Proposal

## Why

IDE-062: SQLLogicTest работает, но SQLS 0.2.48+forge.1 не предоставляет semantic
references. Source RED сохранён в 341aba2/FIXLOG §142. Собственный resolver/index
означал бы сопровождение существенного fork сервера.

Решение владельца 2026-11-10: использовать готовые LSP/backend, не строить своё
language ядро ради полноты. Потребность остаётся открытой; собственный подход
отменён. Перед рефакторингом провести большой обзор фич и наслоений (IDE-080).

## What Changes

- Убрать неподключённые собственные resolver/handler/index и только их tooling.
  Историю и source evidence сохранить.
- Убрать незавершённый acceptance case из рабочего набора; references остаются
  ограничением, фича не объявляется PASS.
- Сравнивать готовые backend по binding/scopes/CTE/DML, unsaved/workspace
  references, диалектам, платформам и стоимости сопровождения.
- При отсутствии подходящего готового решения оставить явное ограничение,
  без grep fallback и самостоятельного language ядра.

## Capabilities

### New Capabilities

- `sql-workflow`: будущее ADDED IDE-SQL-9 через готовый backend. Требование
  невыполнено; IDE-SQL-1–8 и main baseline не переписываются.

### Modified Capabilities

Нет. Текущие query/tests/LSP mappings сохраняются. Отменён подход реализации,
а не потребность в references.

## Impact

Собственный неподключённый prototype/test tooling, planning/docs/history и
registry. Product Lua, 67 pins и SQLS forge.1 не меняются. Будущая интеграция
требует подтверждённого готового кандидата и обычных native/editor E2E.
